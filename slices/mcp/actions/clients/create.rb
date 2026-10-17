# frozen_string_literal: true

require "json"

module MCP
  module Actions
    module Clients
      class Create < Action
        MAX_BYTES = 16_384
        TOO_MANY = "temporarily_unavailable"

        include Deps[
          "operations.read_visitor_address",
          hash_visitor: "analytics.operations.hash_visitor",
          register_client: "operations.register_client",
        ]

        def handle(request, response)
          case register_client.call(payload(request), visitor_hashes: visitor_hashes(request))
            in Success(client)
              render_json(response, client, status: :created)
            in Failure(Operations::RegisterClient::REJECT, payload)
              reject_json(response, payload)
            in Failure(Blog::Throttle::THROTTLED)
              render_json(response, { error: TOO_MANY }, status: :too_many_requests)
            else
              reject_json(response)
          end
        end

        private

        def cross_origin? = false

        def payload(request)
          JSON.parse(request.body.read(MAX_BYTES).to_s)
        rescue JSON::ParserError
          nil
        end

        def visitor_hashes(request) = hash_visitor.throttle_hashes(read_visitor_address.call(request))
      end
    end
  end
end
