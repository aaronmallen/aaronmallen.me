# frozen_string_literal: true

module Security
  module Operations
    class RecordSighting
      include Deps[
        "operations.read_access",
        sighting_mutations: "repos.sighting_mutations",
      ]

      def call(request, api_token_id: nil, oauth_client_id: nil)
        access = read_access.call(request)
        user_agent = access[:user_agent]
        device = { api_token_id:, oauth_client_id:, product: user_agent[%r{\A\s*([^\s/()]+)}, 1] }

        sighting_mutations.sight(**device, **access.slice(*ReadAccess::DEVICE), last_address: access[:address],
                                                                                last_user_agent: user_agent)
      end
    end
  end
end
