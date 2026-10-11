# frozen_string_literal: true

module Blog
  class ShareHost
    CACHE_CONTROL = "private, no-store"

    def initialize(app, host, shares)
      @app = app
      @host = host
      @shares = shares
    end

    def call(env)
      return @app.call(env) unless ::Rack::Request.new(env).host == @host

      status, headers, body = @shares.call(env)
      headers["cache-control"] = CACHE_CONTROL
      [status, headers, body]
    end
  end
end
