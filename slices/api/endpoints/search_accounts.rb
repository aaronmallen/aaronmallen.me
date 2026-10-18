# frozen_string_literal: true

module API
  module Endpoints
    class SearchAccounts < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          network: { type: "string", enum: Blog::Types::NetworkName.values, description: "the network to search" },
          query: {
            type: "string",
            description: "a name or handle to look for; under two characters finds nothing and asks no network",
          },
        },
        required: %w[network query],
      }.freeze
      UNAVAILABLE = true

      REPLY = Helpers::Schema.object({ accounts: Helpers::Schema.list(Serializers::Account.reference) }).freeze

      include Deps[search_accounts: "social.operations.search_accounts"]

      def handle(network:, query:)
        name = network.capitalize

        case search_accounts.call(network:, query:)
          in Success(*accounts) then Success(accounts: serialized(Serializers::Account, accounts))
          in Failure(:unconfigured) then unavailable("#{name} has no credentials, so it cannot be searched")
          in Failure(:rate_limited) then unavailable("#{name} has had too many searches; wait a minute and try again")
          in unmatched then unhandled(unmatched, "#{name} did not answer; try again")
        end
      end

      private

      def unavailable(message) = Failure(Structs::Refusal.unavailable(message))
    end
  end
end
