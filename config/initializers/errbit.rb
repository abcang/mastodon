Airbrake.configure do |config|
  config.host = ENV.fetch('AIRBRAKE_HOST')
  config.project_id = ENV.fetch('AIRBRAKE_PROJECT_ID') # required, but any positive integer works
  config.project_key = ENV.fetch('AIRBRAKE_PROJECT_KEY')

  # Uncomment for Rails apps
  config.environment = Rails.env
  config.ignore_environments = %w(development test)
end
