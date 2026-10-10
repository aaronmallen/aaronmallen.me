# frozen_string_literal: true

module Security
  module Operations
    class RecordSighting
      include Deps[
        "operations.read_access",
        known_device_mutations: "repos.known_device_mutations",
        sighting_mutations: "repos.sighting_mutations",
      ]

      def call(request, api_token_id: nil, oauth_client_id: nil)
        access = read_access.call(request)
        device = { api_token_id:, oauth_client_id:, **access.slice(*ReadAccess::DEVICE) }

        known_device_mutations.know(**device)
        sighting_mutations.sight(**device, last_address: access[:address], last_user_agent: access[:user_agent])
      end
    end
  end
end
