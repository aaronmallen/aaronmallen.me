# frozen_string_literal: true

module Shares
  class Transfers
    FREE_THREADS = 2
    RETRY_SECONDS = "10"

    def initialize(settings)
      @limit = settings.share_site[:transfers] || [settings.web_threads - FREE_THREADS, 1].max
      @lock = Mutex.new
      @count = 0
    end

    def call
      return [503, { "retry-after" => RETRY_SECONDS }, []] unless take

      status, headers, body = yield
      [status, headers, ::Rack::BodyProxy.new(body) { leave }]
    rescue StandardError
      leave
      raise
    end

    private

    def leave = @lock.synchronize { @count -= 1 }

    def take = @lock.synchronize { @count < @limit && (@count += 1) }
  end
end
