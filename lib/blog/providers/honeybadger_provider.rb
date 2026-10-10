# frozen_string_literal: true

require "blog/version"
require "honeybadger/ruby"
require "redis_client"
require "sidekiq"
require "sidekiq/job_retry"

module Blog
  module Providers
    module HoneybadgerProvider
      ATTEMPT_THRESHOLD = Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS
      FILTER_KEYS = %w[
        api_key
        app_password
        authorization
        bluesky_did
        bluesky_handle
        body
        cf_connecting_ip
        code
        cookie
        email
        license_key
        markdown
        mastodon_handle
        note
        parts
        password
        person
        problem
        remote_addr
        reply_to
        salt
        secret
        state
        subject
        token
        visitor_hash
        x_forwarded_for
      ].freeze
      IGNORE = (Honeybadger::Config::IGNORE_DEFAULT | %w[
        Hanami::Router::NotAllowedError
        Hanami::Router::NotFoundError
      ]).freeze
      PRODUCTION = "production"
      SCHEDULER_THREAD = "sidekiq.scheduler"

      class << self
        def agent(settings, env)
          configure(settings.honeybadger, env.to_s)
          Honeybadger.load_plugins!
          Honeybadger.install_at_exit_callback

          Honeybadger::Agent.instance
        end

        private

        def configure(found, env)
          Honeybadger.configure do |config|
            config.api_key = found[:api_key]
            config.env = env
            config.report_data = report_data?(found, env)
            config.revision = Blog::Version::CURRENT
            config.before_notify { quiet_scheduler(it) }
            config.exceptions.ignore = IGNORE
            config.request.filter_keys = FILTER_KEYS
            config.sidekiq.attempt_threshold = ATTEMPT_THRESHOLD
          end
        end

        def quiet_scheduler(notice)
          return unless notice.exception.is_a?(RedisClient::ConnectionError) && Thread.current.name == SCHEDULER_THREAD

          notice.halt!
        end

        def report_data?(honeybadger, env)
          found = honeybadger[:report_data]

          found.nil? ? env == PRODUCTION : found
        end
      end
    end
  end
end
