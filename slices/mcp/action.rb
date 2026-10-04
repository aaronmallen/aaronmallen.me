# auto_register: false
# frozen_string_literal: true

require "json"

module MCP
  class Action < Blog::Action
    ANY_ORIGIN = "*"
    INVALID_REQUEST = "invalid_request"
    JSON_TYPE = "application/json"
    OK = 200
    REJECTED = 400

    private

    def allow_any_origin(response)
      response.headers["Access-Control-Allow-Origin"] = ANY_ORIGIN if cross_origin?
    end

    def cross_origin? = true

    def issuer = Blog::Site.url.chomp("/")

    def reject_json(response) = render_json(response, { error: INVALID_REQUEST }, status: REJECTED)

    def render_body(response, body, status: OK)
      response.status = status
      allow_any_origin(response)
      response.headers["Content-Type"] = JSON_TYPE
      response.body = body
    end

    def render_json(response, payload, status: OK) = render_body(response, JSON.generate(payload), status:)
  end
end
