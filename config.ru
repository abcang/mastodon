# frozen_string_literal: true
# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
use StackProf::Middleware,
    enabled: ENV['ENABLE_STACKPROF'].to_i.nonzero?,
    mode: :wall,
    interval: 1000,
    save_every: 5,
    path: 'tmp/stackprof'
use PG::Connection::GeneralLog::Middleware, enabled: true, path: Rails.root.join('tmp', 'general_log')
run Rails.application
