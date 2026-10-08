# frozen_string_literal: true

module Security
  module Operations
    class RecordSighting < Operation
      include Deps[
        "operations.read_visitor_address",
        find_place: "analytics.operations.find_place",
        known_device_mutations: "repos.known_device_mutations",
        sighting_mutations: "repos.sighting_mutations",
      ]

      def call(request, api_token_id: nil, oauth_client_id: nil)
        access = Access.read(request, read_visitor_address.call(request), find_place)
        device = { api_token_id:, oauth_client_id:, **access.slice(*Access::DEVICE) }

        known_device_mutations.know(**device)
        Success(
          sighting_mutations.sight(**device, last_address: access[:address], last_user_agent: access[:user_agent]),
        )
      end
    end
  end
end
