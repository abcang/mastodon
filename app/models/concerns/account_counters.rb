# frozen_string_literal: true

module AccountCounters
  extend ActiveSupport::Concern

  included do
    has_one :account_stat, inverse_of: :account
    after_save :save_account_stat!
  end

  delegate :statuses_count,
           :statuses_count=,
           :following_count,
           :following_count=,
           :followers_count,
           :followers_count=,
           :increment_count!,
           :decrement_count!,
           :last_status_at,
           to: :account_stat

  def account_stat
    super || build_account_stat
  end

  private

  def save_account_stat!
    return unless association(:account_stat).loaded? && account_stat&.changed?

    account_stat.save!
  rescue ActiveRecord::StaleObjectError
    begin
      stat_attributes = %w(statuses_count following_count followers_count last_status_at)
      stat_change_results = account_stat.changes.slice(*stat_attributes).transform_values(&:last)
      # Since it is executed within a transaction, it is doubtful that it will really reload.
      # Behavior seems to depend on the transaction isolation level.
      account_stat.reload
      account_stat.assign_attributes(stat_change_results)
    rescue ActiveRecord::RecordNotFound
      return
    end

    retry
  end
end
