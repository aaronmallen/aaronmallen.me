# frozen_string_literal: true

module Admin
  module Operations
    class CheckService < Operation
      include Deps[linear: "record.linear.client", networks: "social.networks.all"]

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

      def clients = { "bluesky" => networks.fetch(Blog::Types::NetworkName["bluesky"]), "linear" => linear }
    end
  end
end
