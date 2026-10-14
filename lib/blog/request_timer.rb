# frozen_string_literal: true

require "rack"

module Blog
  class RequestTimer
    AFTER_REPLY = "rack.after_reply"
    ROUTE = "blog.route"
    SERVER_ERROR = 500

    def initialize(app, record)
      @app = app
      @record = record
      Hanami.app.start(:timing)
    end

    def call(env)
      timer = Timer.start
      status = SERVER_ERROR
      status, = response = @app.call(env)
      response
    ensure
      row = { **timer.stop, route: env[ROUTE], verb: env[::Rack::REQUEST_METHOD], status: }
      env[AFTER_REPLY]&.push(-> { @record.call(**row) })
    end
  end
end
