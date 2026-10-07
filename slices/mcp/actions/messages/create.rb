# frozen_string_literal: true

module MCP
  module Actions
    module Messages
      class Create < Action
        ACCEPTED = 202
        AUTHORIZATION = "HTTP_AUTHORIZATION"
        CHALLENGE = "WWW-Authenticate"
        EXPOSED_HEADERS = "Access-Control-Expose-Headers"
        MAX_BYTES = Blog::ParamsGuard::ENCODED_UPLOAD_LIMIT
        NO_BODY = ""
        UNAUTHORIZED = 401
        UNEXPECTED = { error: INVALID_REQUEST }.freeze

        include Deps[
          authenticate: "operations.authenticate",
          handler: "protocol.handler",
          record_sighting: "security.operations.record_sighting",
        ]

        def handle(request, response)
          case authenticate.call(request.env[AUTHORIZATION], issuer:)
            in Success(token) then answer(request, response, token)
            in Failure(Operations::Authenticate::REJECT, payload) then challenge(response, payload)
            else challenge(response, UNEXPECTED)
          end
        end

        private

        def answer(request, response, token)
          record_sighting.call(request, oauth_client_id: token.oauth_client_id)
          payload = request.body.read(MAX_BYTES).to_s
          reply = handler.call(payload, scopes: token.scopes, oauth_client_id: token.oauth_client_id)
          return render_body(response, NO_BODY, status: ACCEPTED) if reply.nil?

          render_body(response, reply)
        end

        def bearer(payload)
          named = payload.key?(:error) ? payload : {}
          fields = named.merge(resource_metadata: routes.url(:mcp_resource_metadata).to_s)

          "Bearer #{fields.map { |name, value| "#{name}=\"#{value}\"" }.join(', ')}"
        end

        def challenge(response, payload)
          response.headers[CHALLENGE] = bearer(payload)
          response.headers[EXPOSED_HEADERS] = CHALLENGE
          render_json(response, payload, status: UNAUTHORIZED)
        end
      end
    end
  end
end
