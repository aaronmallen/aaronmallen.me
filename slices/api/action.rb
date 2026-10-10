# auto_register: false
# frozen_string_literal: true

require "json"

module API
  class Action < Blog::Action
    AUTHORIZATION = "HTTP_AUTHORIZATION"
    BAD_REQUEST = 400
    CHALLENGE = "WWW-Authenticate"
    CREATED = 201
    FORBIDDEN = 403
    INSUFFICIENT_SCOPE = "insufficient_scope"
    MISSING_SCOPE = "this endpoint needs a token with the %s scope"
    NOT_AN_OBJECT = { error: "invalid_json", message: "the body takes a JSON object" }.freeze
    OK = 200
    STATUSES = { failed: 500, invalid: 422, not_found: 404, unavailable: 503 }.freeze
    UNAUTHORIZED = 401
    VERB_SCOPES = { "DELETE" => Blog::Types::OAuthScope["delete"], "GET" => Blog::Types::OAuthScope["read"],
                    "HEAD" => Blog::Types::OAuthScope["read"] }.freeze
    WRITE = Blog::Types::OAuthScope["write"]

    include Deps[
      authenticate: "operations.authenticate",
      record_sighting: "security.operations.record_sighting",
    ]

    config.formats.accept :json
    config.handle_exception BodyParsingError => :refuse_body

    before :forbid_caching, :require_token

    private

    def bearer(error) = error.key?(:error) ? %(Bearer error="#{error[:error]}") : "Bearer"

    def refuse_body(_request, response, _error) = render_json(response, NOT_AN_OBJECT, status: BAD_REQUEST)

    def render_json(response, payload, status: OK)
      response.status = status
      response.format = :json
      response.body = JSON.generate(payload)
    end

    def require_scope(request, response, token)
      scope = required_scope(request)
      return if token.scopes.include?(scope)

      response.format = :json
      response.headers[CHALLENGE] = %(Bearer error="#{INSUFFICIENT_SCOPE}", scope="#{scope}")
      halt FORBIDDEN, JSON.generate({ error: INSUFFICIENT_SCOPE, error_description: format(MISSING_SCOPE, scope) })
    end

    def require_token(request, response)
      case authenticate.call(request.env[AUTHORIZATION])
        in Success(token)
          record_sighting.call(request, api_token_id: token.id)
          require_scope(request, response, token)
          response[:token] = token
        in Failure(error)
          response.format = :json
          response.headers[CHALLENGE] = bearer(error)
          halt UNAUTHORIZED, JSON.generate(error)
      end
    end

    def required_scope(request) = VERB_SCOPES.fetch(request.request_method, WRITE)
  end
end
