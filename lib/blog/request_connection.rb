# frozen_string_literal: true

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
      database.synchronize do
        database.get(Sequel.function(:set_config, "statement_timeout", "#{milliseconds}ms", false))
        @app.call(env)
      end
    end

    private

    def milliseconds = (@statement_timeout.call * 1000).ceil
  end
end
