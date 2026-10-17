# frozen_string_literal: true

module MCP
  module Actions
    module Messages
      class Create < Action
        AUTHORIZATION = "HTTP_AUTHORIZATION"
        CHALLENGE = "WWW-Authenticate"
        EXPOSED_HEADERS = "Access-Control-Expose-Headers"
        GONE_CLIENT = {
          error: Operations::Authenticate::INVALID_TOKEN, error_description: Operations::Authenticate::UNKNOWN_CLIENT,
        }.freeze
        MAX_BYTES = Blog::ParamsGuard::ENCODED_UPLOAD_LIMIT
        NO_BODY = ""
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
          sighted = record_sighting.call(request, oauth_client_id: token.oauth_client_id)
          return challenge(response, GONE_CLIENT) unless sighted

          payload = request.body.read(MAX_BYTES).to_s
          reply = handler.call(payload, scopes: token.scopes, oauth_client_id: token.oauth_client_id)
          return render_body(response, NO_BODY, status: :accepted) if reply.nil?

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
          render_json(response, payload, status: :unauthorized)
        end
      end
    end
  end
end
