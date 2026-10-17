# frozen_string_literal: true

require "sidekiq"

module Blog
  class JobTimer
    include Sidekiq::ServerMiddleware

    FAILED = Types::PerformanceJobOutcome["failed"]
    SUCCEEDED = Types::PerformanceJobOutcome["succeeded"]

    def initialize(record)
      @record = record
      Hanami.app.start(:timing)
    end

    def call(job, _payload, _queue)
      timer = Timer.start
      outcome = FAILED
      yield
      outcome = SUCCEEDED
    ensure
      @record.call(job: job.class.name, outcome:, **timer.stop)
    end
  end
end
