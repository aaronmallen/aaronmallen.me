# frozen_string_literal: true

module Admin
  module Operations
    class CheckService < Blog::Operation
      include Deps[
        github: "record.github.client", linear: "record.linear.client", networks: "social.networks.all",
      ]

      def call(provider, credentials)
        client = step found(clients[provider])

        step account(client, credentials)
      end

      def checks?(provider) = clients.key?(provider)

      private

      def account(client, credentials)
        Success(client.account(**credentials))
      rescue Record::Error, Social::Error => e
        Failure[:refused, e.message]
      end

      def clients
        {
          Blog::Types::ServiceProvider["bluesky"] => networks.fetch(Blog::Types::NetworkName["bluesky"]),
          Blog::Types::ServiceProvider["github"] => github,
          Blog::Types::ServiceProvider["linear"] => linear,
        }
      end
    end
  end
end
