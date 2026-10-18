# frozen_string_literal: true

require "rack"
require "sequel"

module Blog
  class RequestConnection
    def initialize(app, database, statement_timeout)
      @app = app
      @database = database
      @statement_timeout = statement_timeout
    end

    def call(env)
      database = @database.call
      held = hold(database)
      database.get(Sequel.function(:set_config, "statement_timeout", "#{milliseconds}ms", false))
      @app.call(env)
    ensure
      release = ->(*) { held.resume if held&.alive? }
      finished = env[::Rack::RACK_RESPONSE_FINISHED]
      finished ? finished << release : release.call
    end

    private

    def hold(database) = Fiber.new { database.synchronize { Fiber.yield } }.tap(&:resume)

    def milliseconds = (@statement_timeout.call * 1000).ceil
  end
end
