# frozen_string_literal: true

module Blog
  class StrictTransport
    HEADER = "strict-transport-security"
    VALUE = "max-age=31536000"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers[HEADER] = VALUE
      [status, headers, body]
    end
  end
end
