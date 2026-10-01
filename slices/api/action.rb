# auto_register: false
# frozen_string_literal: true

require "json"

module API
  class Action < Blog::Action
    AUTHORIZATION = "HTTP_AUTHORIZATION"
    CHALLENGE = "WWW-Authenticate"
    OK = 200
    UNAUTHORIZED = 401

    include Deps[authenticate: "operations.authenticate"]

    config.formats.accept :json

    before :forbid_caching, :require_token

    private

    def bearer(error) = error.key?(:error) ? %(Bearer error="#{error[:error]}") : "Bearer"

    def render_json(response, payload, status: OK)
      response.status = status
      response.format = :json
      response.body = JSON.generate(payload)
    end

    def require_token(request, response)
      case authenticate.call(request.env[AUTHORIZATION])
      in Success(token) then response[:token] = token
      in Failure(error)
        response.format = :json
        response.headers[CHALLENGE] = bearer(error)
        halt UNAUTHORIZED, JSON.generate(error)
      end
    end
  end
end
