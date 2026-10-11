# frozen_string_literal: true

module Health
  module Jobs
    class BackfillHealth < Blog::Job
      include Deps[sync_health: "operations.sync_health"]

      sidekiq_options retry: 3

      def perform(last)
        last = Date.iso8601(last)
        first = last - Operations::SyncHealth::CHUNK_DAYS + 1

        case sync_health.call(first, last)
          in Success(0) then nil
          in Success then self.class.perform_async((first - 1).iso8601)
          in Failure(_, message) then raise Error, message
        end
      end
    end
  end
end
