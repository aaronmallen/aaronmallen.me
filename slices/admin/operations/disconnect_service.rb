# frozen_string_literal: true

module Admin
  module Operations
    class DisconnectService < Blog::Operation
      GITHUB = Blog::Types::ServiceProvider["github"]
      GOOGLE = Blog::Types::ServiceProvider["google"]
      LINKEDIN = Blog::Types::ServiceProvider["linkedin"]
      MASTODON = Blog::Types::ServiceProvider["mastodon"]

      include Deps[
        connection_queries: "services.repos.connection_queries",
        github: "github.auth",
        google: "google.client",
        honeybadger: "honeybadger.agent",
        linkedin: "linkedin.auth",
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
          when GITHUB then revoke_token(github, connection)
          when GOOGLE then revoke_google(connection)
          when LINKEDIN then revoke_token(linkedin, connection)
          when MASTODON then revoke_mastodon(connection)
        end
      rescue OAuth2::Error, Faraday::Error => e
        honeybadger.notify(e)
      end

      def revoke_google(connection)
        google.revoke(connection.credentials) if google.configured?
      end

      def revoke_mastodon(connection)
        credentials = connection.credentials
        mastodon.revoke(connection.host, credentials, credentials.fetch(:access_token))
      end

      def revoke_token(auth, connection)
        auth.revoke(connection.credentials.fetch(:access_token)) if auth.configured?
      end
    end
  end
end
