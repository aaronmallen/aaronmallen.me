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

    def call(job, payload, _queue)
      timer = Timer.start
      result = { outcome: FAILED, schedule_key: schedule_key(job, payload) }
      yield
      result[:outcome] = SUCCEEDED
    rescue Exception => e # rubocop:disable Lint/RescueException
      result[:error_class] = e.class.name
      result[:error_message] = e.message
      raise
    ensure
      @record.call(job: job.class.name, **result, **timer.stop)
    end

    private

    def schedule_key(job, payload) = (job.class.check_in_name(*payload["args"]) if job.is_a?(ScheduledJob))
  end
end
