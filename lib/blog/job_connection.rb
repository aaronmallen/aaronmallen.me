# frozen_string_literal: true

require "sidekiq"

module Blog
  class JobConnection
    include Sidekiq::ServerMiddleware

    def initialize(database)
      @database = database
    end

    def call(_job, _payload, _queue, &) = @database.call.synchronize(&)
  end
end
