# frozen_string_literal: true

require "blog/concurrency"
require "cgi"
require "sequel"
require "uri"

module Blog
  module Providers
    module DBProvider
      SPARE_CONNECTIONS = 1
      VALIDATE_EVERY_CHECKOUT = -1
      VALIDATED_CONNECTIONS = :validated_connections

      Sequel::Database.register_extension(VALIDATED_CONNECTIONS) do |db|
        db.extension(:connection_validator)
        db.pool.connection_validation_timeout = VALIDATE_EVERY_CHECKOUT
      end

      class << self
        def configure(config, settings)
          database = settings.database

          config.gateway :default do |gateway|
            gateway.database_url = database_url(database)
            gateway.connection_options(max_connections: max_connections(settings))

            gateway.adapter :sql do |sql|
              sql.extension :date_arithmetic, VALIDATED_CONNECTIONS
            end
          end
        end

        def database_url(database)
          URI::Generic.build(
            path: "/#{database[:name]}",
            scheme: "postgres",
            userinfo: userinfo(database),
            **database.slice(:host, :port),
          ).to_s
        end

        def max_connections(settings)
          [Concurrency.threads + SPARE_CONNECTIONS, settings.database[:max_connections]].min
        end

        private

        def userinfo(database)
          password, user = database.values_at(:password, :user)

          if password.nil?
            user && CGI.escapeURIComponent(user)
          else
            [user.to_s, password].map { CGI.escapeURIComponent(it) }.join(":")
          end
        end
      end
    end
  end
end
