# auto_register: false
# frozen_string_literal: true

require "json"

module API
  class Action < Blog::Action
    AUTHORIZATION = "HTTP_AUTHORIZATION"
    CHALLENGE = "WWW-Authenticate"
    GONE_TOKEN = {
      error: Operations::Authenticate::INVALID_TOKEN, error_description: Operations::Authenticate::UNUSABLE_TOKEN,
    }.freeze
    INSUFFICIENT_SCOPE = "insufficient_scope"
    MISSING_SCOPE = "this endpoint needs a token with the %s scope"
    NOT_AN_OBJECT = { error: "invalid_json", message: "the body takes a JSON object" }.freeze
    STATUSES = {
      failed: :internal_server_error,
      invalid: :unprocessable_content,
      not_found: :not_found,
      unavailable: :service_unavailable,
    }.freeze

    include Deps[
      authenticate: "operations.authenticate",
      record_sighting: "security.operations.record_sighting",
    ]

    config.formats.accept :json
    config.handle_exception BodyParsingError => :refuse_body

    before :forbid_caching, :require_token

    private

    def bearer(error) = error.key?(:error) ? %(Bearer error="#{error[:error]}") : "Bearer"

    def insufficient(response, scope, description = format(MISSING_SCOPE, scope))
      response.format = :json
      response.headers[CHALLENGE] = %(Bearer error="#{INSUFFICIENT_SCOPE}", scope="#{scope}")
      halt :forbidden, JSON.generate({ error: INSUFFICIENT_SCOPE, error_description: description })
    end

    def refuse_body(_request, response, _error) = render_json(response, NOT_AN_OBJECT, status: :bad_request)

    def refuse_token(response, error)
      response.format = :json
      response.headers[CHALLENGE] = bearer(error)
      halt :unauthorized, JSON.generate(error)
    end

    def render_json(response, payload, status: :ok)
      response.status = status
      response.format = :json
      response.body = JSON.generate(payload)
    end

    def require_scope(response, token)
      scope = required_scope.find { !token.scopes.include?(it) }
      insufficient(response, scope) if scope
    end

    def require_token(request, response)
      case authenticate.call(request.env[AUTHORIZATION])
        in Success(token)
          refuse_token(response, GONE_TOKEN) unless record_sighting.call(request, api_token_id: token.id)
          require_scope(response, token)
          response[:token] = token
        in Failure(error)
          refuse_token(response, error)
      end
    end

    def required_scope = OperationTable::SCOPES.fetch(self.class::OPERATION)
  end
end
