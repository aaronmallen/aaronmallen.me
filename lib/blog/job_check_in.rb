# frozen_string_literal: true

require "sidekiq"

module Blog
  class JobCheckIn
    include Sidekiq::ServerMiddleware

    def call(job, payload, _queue)
      yield
      job.check_in(*payload["args"]) if job.is_a?(ScheduledJob)
    end
  end
end
