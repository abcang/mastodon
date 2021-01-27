# frozen_string_literal: true
# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
use PG::Connection::GeneralLog::Middleware, enabled: true, path: Rails.root.join('tmp', 'general_log')
run Rails.application
