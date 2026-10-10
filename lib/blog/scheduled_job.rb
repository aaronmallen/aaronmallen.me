# frozen_string_literal: true

module Blog
  class ScheduledJob < Job
    sidekiq_options retry: false

    private

    def record_and_raise(recorder, failure, error)
      recorder.call(failure)
      raise error
    end
  end
end
