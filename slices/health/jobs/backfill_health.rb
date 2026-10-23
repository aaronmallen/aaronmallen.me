# frozen_string_literal: true

module Health
  module Jobs
    class BackfillHealth < Blog::Job
      OLDER = {
        "sleep" => "sleep.interval.end_time < %<start>s",
        "daily-resting-heart-rate" => "daily_resting_heart_rate.date < %<day>s",
        "daily-heart-rate-variability" => "daily_heart_rate_variability.date < %<day>s",
        "exercise" => "exercise.interval.civil_start_time < %<day>s",
      }.freeze

      include Deps[google: "google.client", sync_health: "operations.sync_health"]

      def perform(last)
        last = Date.iso8601(last)
        first = last - Operations::SyncHealth::CHUNK_DAYS + 1
        client = google.loaded

        case sync_health.call(first, last, client)
          in Success(0) then walk_on(first) if older?(client, first)
          in Success then walk_on(first)
          in Failure(_, message) then raise Error, message
        end
      end

      private

      def older?(client, first)
        account = client.holding(Operations::SyncHealth::SCOPE)&.then { Google::Account.new(client, it) }
        bounds = { day: %("#{first.iso8601}"), start: %("#{Blog::TimeZone.day_start(first).utc.iso8601}") }

        account && OLDER.any? { |type, filter| older_points?(account, type, format(filter, bounds)) }
      rescue Google::Error => e
        raise Error, e.message
      end

      def older_points?(account, type, filter)
        url = google.url(:health, "users/me/dataTypes/#{type}/dataPoints")

        account.get(url, narrow: Operations::SyncHealth::SCOPE, filter:, page_size: 1).fetch("dataPoints", []).any?
      end

      def walk_on(first) = self.class.perform_async((first - 1).iso8601)
    end
  end
end
