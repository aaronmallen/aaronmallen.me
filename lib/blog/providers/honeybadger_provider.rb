# frozen_string_literal: true

require "blog/version"
require "honeybadger/ruby"
require "sidekiq"
require "sidekiq/job_retry"

module Blog
  module Providers
    module HoneybadgerProvider
      ATTEMPT_THRESHOLD = Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS
      FILTER_KEYS = %w[
        api_key
        authorization
        body
        cf_connecting_ip
        code
        cookie
        email
        license_key
        password
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

      class << self
        def agent(settings, env)
          chosen = options(settings, env)

          Honeybadger.configure { apply(it, chosen) }
          Honeybadger.load_plugins!
          Honeybadger.install_at_exit_callback

          Honeybadger::Agent.instance
        end

        def options(settings, env)
          found = settings.honeybadger

          {
            api_key: found[:api_key],
            attempt_threshold: ATTEMPT_THRESHOLD,
            env: env.to_s,
            filter_keys: FILTER_KEYS,
            ignore: IGNORE,
            report_data: report_data?(found, env),
            revision: Blog::Version::CURRENT,
          }
        end

        private

        def apply(config, chosen)
          config.api_key = chosen[:api_key]
          config.env = chosen[:env]
          config.report_data = chosen[:report_data]
          config.revision = chosen[:revision]
          apply_sections(config, chosen)
        end

        def apply_sections(config, chosen)
          config.exceptions.ignore = chosen[:ignore]
          config.request.filter_keys = chosen[:filter_keys]
          config.sidekiq.attempt_threshold = chosen[:attempt_threshold]
        end

        def report_data?(honeybadger, env)
          found = honeybadger[:report_data]

          found.nil? ? env.to_s == PRODUCTION : found
        end
      end
    end
  end
end
