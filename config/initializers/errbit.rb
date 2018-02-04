Airbrake.configure do |config|
  config.host = ENV.fetch('AIRBRAKE_HOST')
  config.project_id = ENV.fetch('AIRBRAKE_PROJECT_ID') # required, but any positive integer works
  config.project_key = ENV.fetch('AIRBRAKE_PROJECT_KEY')

  # Uncomment for Rails apps
  config.environment = Rails.env
  config.ignore_environments = %w(development test)
end

ERRBIT_IGNORE_ERRORS = %w[
  Mastodon::UnexpectedResponseError
  OpenSSL::SSL::SSLError
  Excon::Error::ServiceUnavailable
  Excon::Error::Timeout
  ActiveRecord::ConnectionTimeoutError
  SignalException
].freeze

ERRBIT_IGNORE_WORKER_ERRORS = {
  'ActiveRecord::RecordInvalid' => ['ActivityPub::ProcessingWorker']
}.freeze

Airbrake.add_filter do |notice|
  if notice[:errors].any? { |error|
    error[:type].constantize.ancestors.include?(HTTP::Error) ||
    ERRBIT_IGNORE_ERRORS.include?(error[:type]) ||
    ERRBIT_IGNORE_WORKER_ERRORS[error[:type]]&.inclide?(notice[:params].dig('job', 'class'))
  }
    notice.ignore!
  end
end
