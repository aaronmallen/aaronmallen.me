# frozen_string_literal: true

module Record
  module SyncBookkeeping
    include Dry::Monads[:result]

    def self.included(job) = job.include(Deps["operations.record_sync_outcome"])

    private

    def record_and_raise(sync, failure, error)
      record_sync_outcome.call(sync, failure)
      raise error
    end

    def record_crash(sync, reason = :crashed)
      yield
    rescue StandardError => e
      record_and_raise(sync, Failure([reason, e.message]), e)
    end

    def record_outcome(sync, result)
      case result
        in Failure(:lock_busy) then nil
        else record_sync_outcome.call(sync, result)
      end
    end

    def record_sync(sync, &) = record_outcome(sync, record_crash(sync, &))
  end
end
