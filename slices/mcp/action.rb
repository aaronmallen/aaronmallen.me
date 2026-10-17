# auto_register: false
# frozen_string_literal: true

require "json"

module MCP
  class Action < Blog::Action
    ANY_ORIGIN = "*"
    INVALID_REQUEST = "invalid_request"
    JSON_TYPE = "application/json"

    include Deps["settings"]

    private

    def allow_any_origin(response)
      response.headers["Access-Control-Allow-Origin"] = ANY_ORIGIN if cross_origin?
    end

    def cross_origin? = true

    def issuer = settings.site_url.chomp("/")

    def reject_json(response, payload = { error: INVALID_REQUEST })
      render_json(response, payload, status: :bad_request)
    end

    def render_body(response, body, status: :ok)
      response.status = status
      allow_any_origin(response)
      response.headers["Content-Type"] = JSON_TYPE
      response.body = body
    end

    def render_json(response, payload, status: :ok) = render_body(response, JSON.generate(payload), status:)
  end
end
