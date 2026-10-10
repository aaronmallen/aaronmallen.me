# frozen_string_literal: true

module Blog
  class ScheduledJob < Job
    sidekiq_options retry: false

    private

    def record_and_raise(sync, failure, error)
      record_sync_outcome.call(sync, failure)
      raise error
    end
  end
end
