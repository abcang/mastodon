# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']

  config.enabled_environments = %w[production]

  config.excluded_exceptions += %w[
    ActionController::InvalidAuthenticityToken
    ActionController::BadRequest
    ActionController::UnknownFormat
    ActionController::ParameterMissing
    ActiveRecord::RecordNotUnique
    Mastodon::UnexpectedResponseError
    Mastodon::RaceConditionError
    Mastodon::HostValidationError

    Fog::Storage::OpenStack::NotFound
    Excon::Error::Forbidden
    Excon::Error::BadRequest
  ]

  config.traces_sample_rate = 0.005

  config.before_send = ->(event, hint) do
    return if ShouldCaptureChecker.ignore?(event)

    event
  end
end

module ShouldCaptureChecker
  NETWORK_EXCEPTIONS = %w[
    HTTP::StateError
    HTTP::TimeoutError
    HTTP::ConnectionError
    HTTP::Redirector::TooManyRedirectsError
    HTTP::Redirector::EndlessRedirectError
    OpenSSL::SSL::SSLError
    Stoplight::Error::RedLight
    Net::ReadTimeout
  ].freeze

  NETWORK_WORKERS = %w[
    LinkCrawlWorker
    ProcessingWorker
    ThreadResolveWorker
    NotificationWorker
    Import::RelationshipWorker
    Web::PushNotificationWorker
    RedownloadMediaWorker
  ].freeze

  NETWORK_CONTROLLERS_OR_CONCERNS = %w[
    RemoteFollowController
    AuthorizeFollowsController
    SignatureVerification
  ].freeze

  IGNORE_WORKER_ERRORS = {
    'ActivityPub::ProcessingWorker' => ['ActiveRecord::RecordInvalid'],
    'LinkCrawlWorker' => ['ActiveRecord::RecordInvalid'],
  }.freeze

  IGNORE_JOB_ERRORS = {
    'ActionMailer::DeliveryJob' => ['ActiveJob::DeserializationError']
  }.freeze

  IGNORE_CONTROLLER_ERRORS = {
    'MediaProxyController' => ['ActiveRecord::RecordInvalid'],
  }.freeze

  class << self
    def ignore?(event)
      return false unless event.exception

      exception_name = event.exception.values.last.type
      transaction = event.transaction
      return true if ignore_by_sidekiq(transaction, exception_name)
      return true if ignore_by_controller(transaction, exception_name)

      false
    end

    private

    def ignore_by_sidekiq(transaction, exception_name)
      return false unless transaction&.start_with?('Sidekiq/')

      worker_class = transaction.split('Sidekiq/').last
      return true if IGNORE_WORKER_ERRORS[worker_class]&.include?(exception_name)

      # ActivityPub or 通信が頻繁に発生するWorkerではネットワーク系の例外を無視
      if worker_class.start_with?('ActivityPub::') || NETWORK_WORKERS.include?(worker_class)
        return true if NETWORK_EXCEPTIONS.include?(exception_name)
      end

      # ActiveJob
      if worker_class == 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper'
        return true if IGNORE_JOB_ERRORS[sidekiq.dig('wrapped')]&.include?(exception_name)
      end

      false
    end

    def ignore_by_controller(transaction, exception_name)
      return false unless transaction&.include?('#')

      controller_class_name = transaction.split('#').first
      return true if IGNORE_CONTROLLER_ERRORS[controller_class_name]&.include?(exception_name)

      # SignatureVerificationがincludeされているコントローラ or 通信が頻繁に発生するコントローラではネットワーク系のエラーを無視
      if controller_class_name.constantize.ancestors.any? { |klass| NETWORK_CONTROLLERS_OR_CONCERNS.include?(klass.name) }
        return true if NETWORK_EXCEPTIONS.include?(exception_name)
      end

      false
    end
  end
end
