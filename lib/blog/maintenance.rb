# frozen_string_literal: true

require "json"
require "openssl"

module Blog
  class Maintenance
    COOKIE = "maintenance.owner"
    DIGEST = "SHA256"
    JSON_BODY = JSON.generate({ error: "temporarily_unavailable", message: "the site is down for maintenance" })
    JSON_PATHS = %r{\A/(?:api/|mcp\z|oauth/(?:register|token)\z|\.well-known/oauth-)}
    MILLISECONDS = 1_000
    PAGE = File.expand_path("../../public/503.html", __dir__)
    PURPOSE = "maintenance-owner"
    RETRY_SECONDS = "300"
    SEPARATOR = "--"

    def self.pass(secret, at)
      issued = (at.to_r * MILLISECONDS).floor
      "#{issued}#{SEPARATOR}#{OpenSSL::HMAC.hexdigest(DIGEST, secret, "#{PURPOSE}:#{issued}")}"
    end

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
