# frozen_string_literal: true

require "json"

module Blog
  class Maintenance
    JSON_BODY = JSON.generate({ error: "temporarily_unavailable", message: "the site is down for maintenance" })
    JSON_PATHS = %r{\A/(?:api/|mcp\z|oauth/(?:register|token)\z|\.well-known/oauth-)}
    PAGE = File.expand_path("../../public/503.html", __dir__)
    RETRY_SECONDS = "300"

    def initialize(app, flag)
      @app = app
      @flag = flag
      @page = File.read(PAGE)
    end

    def call(env)
      return @app.call(env) unless File.exist?(@flag)

      type, body = JSON_PATHS.match?(env[::Rack::PATH_INFO]) ? ["application/json", JSON_BODY] : ["text/html", @page]
      headers = { "cache-control" => "no-store", "content-type" => type, "retry-after" => RETRY_SECONDS }
      [::Rack::Utils.status_code(:service_unavailable), headers, [body]]
    end
  end
end
