# frozen_string_literal: true

module Blog
  class RequestConnection
    def initialize(app, database)
      @app = app
      @database = database
    end

    def call(env) = @database.call.synchronize { @app.call(env) }
  end
end
