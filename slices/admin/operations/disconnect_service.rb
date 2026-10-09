# frozen_string_literal: true

module Admin
  module Operations
    class DisconnectService < Operation
      GITHUB = "github"

      include Deps[
        connection_queries: "services.repos.connection_queries",
        github: "github.auth",
        honeybadger: "honeybadger.agent",
        remove_connection: "services.operations.remove_connection",
      ]

      def call(id)
        connection = step found(connection_queries.by_id(id))
        revoke(connection)

        step remove_connection.call(id)
      end

      private

      def revoke(connection)
        return unless connection.provider == GITHUB && github.configured?

        github.revoke(connection.credentials.fetch(:access_token))
      rescue OAuth2::Error, Faraday::Error => e
        honeybadger.notify(e)
      end
    end
  end
end
