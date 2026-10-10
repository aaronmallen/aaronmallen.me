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
    SCOPE = nil
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

    def answer(response, result)
      case result
        in Success(payload) then render_json(response, payload, status: success_status)
        in Failure(Structs::Refusal => refusal)
          render_json(response, refusal.to_h, status: STATUSES.fetch(refusal.error))
      end
    end

    def bearer(error) = error.key?(:error) ? %(Bearer error="#{error[:error]}") : "Bearer"

    def body(request, response)
      parsed = request.env.fetch(ACTION_PARSED_BODY, Blog::Constants::EMPTY_HASH)
      return parsed if parsed.is_a?(Hash)

      response.format = :json
      halt BAD_REQUEST, JSON.generate(NOT_AN_OBJECT)
    end

    def number(value) = Blog::Types::IntegerParam[value]

    def paged_query(request, *keys)
      found = query(request, *keys, :page)
      found.key?(:page) ? found.merge(page: number(found[:page])) : found
    end

    def query(request, *keys) = keys.to_h { [it, request.params[it]] }.compact

    def record_id(request) = number(request.params[:id])

    def refuse_body(_request, response, _error) = render_json(response, NOT_AN_OBJECT, status: BAD_REQUEST)

    def render_json(response, payload, status: OK)
      response.status = status
      response.format = :json
      response.body = JSON.generate(payload)
    end

    def require_scope(request, response, token)
      scope = self.class::SCOPE || VERB_SCOPES.fetch(request.request_method, WRITE)
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

    def split(values) = Blog::Types::ListParam[values]

    def success_status
      Operations::BuildDocument::SUCCESSES.fetch(Hanami.app.inflector.underscore(endpoint.class.name.split("::").last))
    end
  end
end
