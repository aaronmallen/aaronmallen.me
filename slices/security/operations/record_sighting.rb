# frozen_string_literal: true

module Security
  module Operations
    class RecordSighting < Operation
      include Deps[
        find_place: "analytics.operations.find_place",
        sighting_mutations: "repos.sighting_mutations",
      ]

      def call(request, api_token_id: nil, oauth_client_id: nil)
        access = Access.read(request, find_place)

        Success(
          sighting_mutations.sight(
            api_token_id:, oauth_client_id:, browser: access[:browser], os: access[:os], city: access[:city],
            country: access[:country], last_address: access[:address], last_user_agent: access[:user_agent],
          ),
        )
      end
    end
  end
end
