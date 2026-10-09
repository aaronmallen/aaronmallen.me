# frozen_string_literal: true

module Admin
  module Operations
    class DisconnectService < Operation
      GITHUB = "github"
      MASTODON = "mastodon"

      include Deps[
        connection_queries: "services.repos.connection_queries",
        github: "github.auth",
        honeybadger: "honeybadger.agent",
        mastodon: "mastodon.auth",
        remove_connection: "services.operations.remove_connection",
      ]

      def call(id)
        connection = step found(connection_queries.by_id(id))
        revoke(connection)

        step remove_connection.call(id)
      end

      private

      def revoke(connection)
        return if connection.by_credentials?

        case connection.provider
          when GITHUB then github.revoke(connection.credentials.fetch(:access_token)) if github.configured?
          when MASTODON then revoke_mastodon(connection)
        end
      rescue OAuth2::Error, Faraday::Error => e
        honeybadger.notify(e)
      end

      def revoke_mastodon(connection)
        credentials = connection.credentials
        mastodon.revoke(connection.host, credentials, credentials.fetch(:access_token))
      end
    end
  end
end
