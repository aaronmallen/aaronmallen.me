# frozen_string_literal: true

require "fileutils"
require "json"
require "openssl"

module Blog
  class Maintenance
    BUTTON = <<~HTML
      <form method="post" action="/maintenance/deactivate">
        <button type="submit">Deactivate maintenance mode</button>
      </form>
    HTML
    BUTTON_STYLE = <<~CSS

      button {
        min-height: 44px;
        margin-top: 1rem;
        padding: 0.5rem 1rem;
        border: 1px solid var(--accent);
        border-radius: 0.375rem;
        background: none;
        color: var(--accent);
        font: inherit;
        font-weight: 700;
        cursor: pointer;
      }
    CSS
    COOKIE = "maintenance.owner"
    DEACTIVATE_PATH = "/maintenance/deactivate"
    DIGEST = "SHA256"
    JSON_BODY = JSON.generate({ error: "temporarily_unavailable", message: "the site is down for maintenance" })
    JSON_PATHS = %r{\A/(?:api/|mcp\z|oauth/(?:register|token)\z|\.well-known/oauth-)}
    MILLISECONDS = 1_000
    PAGE = File.expand_path("../../public/503.html", __dir__)
    PURPOSE = "maintenance-owner"
    RETRY_SECONDS = "300"
    SEPARATOR = "--"
    SETTINGS_PATH = "/admin/settings/security"

    def self.milliseconds(at) = (at.to_r * MILLISECONDS).floor

    def self.pass(secret, at)
      issued = milliseconds(at)
      "#{issued}#{SEPARATOR}#{sign(secret, issued)}"
    end

    def self.sign(secret, issued) = OpenSSL::HMAC.hexdigest(DIGEST, secret, "#{PURPOSE}:#{issued}")

    def initialize(app, flag, secret)
      @app = app
      @flag = flag
      @secret = secret
      @page = File.read(PAGE)
      style = BUTTON_STYLE.gsub(/^(?=.)/, "      ")
      button = BUTTON.gsub(/^/, "      ")
      @owner_page = @page.sub("    </style>", "#{style}    </style>").sub("    </main>", "#{button}    </main>")
    end

    def call(env)
      flagged_at = File.mtime(@flag)
    rescue Errno::ENOENT
      @app.call(env)
    else
      request = ::Rack::Request.new(env)
      owner = owner?(request.cookies[COOKIE], flagged_at)
      return deactivate if owner && request.post? && request.path_info == DEACTIVATE_PATH

      unavailable(request.path_info, owner)
    end

    private

    def deactivate
      FileUtils.rm_f(@flag)
      headers = { "cache-control" => "no-store", "location" => SETTINGS_PATH }
      ::Rack::Utils.delete_cookie_header!(headers, COOKIE, path: "/")
      [::Rack::Utils.status_code(:see_other), headers, []]
    end

    def owner?(cookie, flagged_at)
      issued, signature = cookie.to_s.split(SEPARATOR, 2)
      issued = Integer(issued, 10, exception: false)
      return false unless issued && signature

      ::Rack::Utils.secure_compare(self.class.sign(@secret, issued), signature) &&
        issued >= self.class.milliseconds(flagged_at)
    end

    def reply(type, body)
      headers = { "cache-control" => "no-store", "content-type" => type, "retry-after" => RETRY_SECONDS }
      [::Rack::Utils.status_code(:service_unavailable), headers, [body]]
    end

    def unavailable(path, owner)
      return reply("application/json", JSON_BODY) if JSON_PATHS.match?(path)

      reply("text/html", owner ? @owner_page : @page)
    end
  end
end
