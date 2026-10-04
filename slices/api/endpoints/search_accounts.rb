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

      REPLY = Schema.object({ accounts: Schema.list(Serializers::Account.reference) }).freeze

      include Deps[search_accounts: "social.operations.search_accounts"]

      def handle(network:, query:)
        name = network.capitalize

        case search_accounts.call(network:, query:)
        in Success(*accounts) then Success(accounts: serialized(Serializers::Account, accounts))
        in Failure(:unconfigured) then not_found("#{name} has no credentials, so it cannot be searched")
        in Failure(:rate_limited) then failed("#{name} has had too many searches; wait a minute and try again")
        else failed("#{name} did not answer; try again")
        end
      end
    end
  end
end
