# frozen_string_literal: true

require "json"

module MCP
  module Actions
    module Clients
      class Create < Action
        CREATED = 201
        MAX_BYTES = 16_384
        THROTTLED = 429
        TOO_MANY = "temporarily_unavailable"

        include Deps[
          hash_visitor: "analytics.operations.hash_visitor",
          register_client: "operations.register_client",
        ]

        def handle(request, response)
          case register_client.call(payload(request), visitor_hash: visitor_hash(request))
            in Success(client)
              render_json(response, client, status: CREATED)
            in Failure(Operations::RegisterClient::REJECT, payload)
              render_json(response, payload, status: REJECTED)
            in Failure(Operations::RegisterClient::THROTTLED)
              render_json(response, { error: TOO_MANY }, status: THROTTLED)
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

        def visitor_hash(request)
          hash_visitor.call(address: Blog::ThrottleKey.call(Blog::VisitorAddress.call(request)))
        end
      end
    end
  end
end
