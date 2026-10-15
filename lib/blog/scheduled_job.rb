# frozen_string_literal: true

module Blog
  class ScheduledJob < Job
    module CheckIn
      def perform(*args)
        super.tap { check_in(args) }
      end
    end

    include Deps["settings", honeybadger: "honeybadger.agent"]

    sidekiq_options retry: false

    def self.check_in_name(*args) = [Hanami.app.inflector.underscore(name.split("::").last), *args].join("_")

    def self.inherited(job)
      super
      job.prepend(CheckIn)
    end

    private

    def check_in(args)
      id = settings.honeybadger.fetch(:check_ins, {})[self.class.check_in_name(*args)]
      honeybadger.check_in(id) if id
    end

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
  end
end
