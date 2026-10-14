# frozen_string_literal: true

module API
  module Endpoints
    class ListClients < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ clients: Helpers::Schema.list(Serializers::Client.reference) }).freeze

      include Deps["repos.client_queries"]

      def handle
        clients = client_queries.connected

        Success(clients: serialized(Serializers::Client, clients,
                                    scopes: client_queries.granted_scopes(clients.map(&:id))))
      end
    end
  end
end
