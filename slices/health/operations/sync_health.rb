# frozen_string_literal: true

module Health
  module Operations
    class SyncHealth < Blog::Operation
      CHUNK_DAYS = 90
      DATA_TYPES = "https://health.googleapis.com/v4/users/me/dataTypes"
      EMPTY_DAY = {
        minutes_asleep: nil, bed_at: nil, woke_at: nil, resting_heart_rate: nil, hrv: nil, steps: nil,
        active_zone_minutes: nil,
      }.freeze
      SCOPE = "https://www.googleapis.com/auth/googlehealth."
      READERS = %i[nights resting_heart_rates hrvs step_counts zone_minutes].freeze
      ZONES = %w[sumInFatBurnHeartZone sumInCardioHeartZone sumInPeakHeartZone].freeze

      include Deps[google: "google.google.client", health_mutations: "repos.health_mutations"]

      def call(first, last) = step synced(first, last)

      private

      def civil(date) = { date: { year: date.year, month: date.month, day: date.day } }

      def date(value) = Date.new(*value.values_at("year", "month", "day"))

      def days(account, first, last)
        found = READERS.map { send(it, account, first, last) }

        (first..last).filter_map do |day|
          row = found.map { it.fetch(day, {}) }.reduce(:merge)
          { **EMPTY_DAY, day:, **row } unless row.compact.empty?
        end
      end

      def hrvs(account, first, last)
        summaries(account, "daily-heart-rate-variability", "daily_heart_rate_variability", first, last) do |summary|
          { hrv: summary["averageHeartRateVariabilityMilliseconds"] }
        end
      end

      def metrics(summary)
        {
          distance_meters: summary["distanceMillimeters"]&./(1000.0),
          average_heart_rate: summary["averageHeartRateBeatsPerMinute"]&.to_i,
          zone_minutes: summary["activeZoneMinutes"]&.to_i, kcal: summary["caloriesKcal"]&.round,
        }
      end

      def night(sessions)
        asleep = sessions.map { it.dig("summary", "minutesAsleep").to_i }
        main = sessions[asleep.index(asleep.max)].fetch("interval")

        { minutes_asleep: asleep.sum, bed_at: Time.iso8601(main["startTime"]), woke_at: Time.iso8601(main["endTime"]) }
      end

      def nights(account, first, last)
        bounds = Blog::TimeZone.day_bounds(first, last).map { %("#{it.utc.iso8601}") }
        filter = "sleep.interval.end_time >= #{bounds[0]} AND sleep.interval.end_time < #{bounds[1]}"
        nights = points(account, "sleep", filter).map { it["sleep"] }

        nights.group_by { Blog::TimeZone.today(Time.iso8601(it.dig("interval", "endTime"))) }
              .transform_values { night(it) }
      end

      def points(account, type, filter, **params)
        page = google.get("#{DATA_TYPES}/#{type}/dataPoints", account:, filter:, **params)
        rows = page.fetch("dataPoints", [])
        token = page["nextPageToken"].to_s
        token.empty? ? rows : rows + points(account, type, filter, **params, page_token: token)
      end

      def resting_heart_rates(account, first, last)
        summaries(account, "daily-resting-heart-rate", "daily_resting_heart_rate", first, last) do |summary|
          { resting_heart_rate: summary["beatsPerMinute"]&.to_i }
        end
      end

      def rollup(account, type, first, last)
        body = { range: { start: civil(first), end: civil(last + 1) }, windowSizeDays: 1 }
        page = google.post("#{DATA_TYPES}/#{type}/dataPoints:dailyRollUp", body, account:)
        rows = page.fetch("rollupDataPoints", [])

        rows.to_h { [date(it.dig("civilStartTime", "date")), yield(it)] }
      end

      def step_counts(account, first, last)
        rollup(account, "steps", first, last) { { steps: it.dig("steps", "countSum")&.to_i } }
      end

      def summaries(account, type, field, first, last)
        filter = %(#{field}.date >= "#{first.iso8601}" AND #{field}.date < "#{(last + 1).iso8601}")

        points(account, type, filter).to_h { [date(it.dig(field, "date")), yield(it[field])] }
      end

      def sync(account, first, last)
        health_mutations.store(days: days(account, first, last), workouts: workouts(account, first, last))
      end

      def synced(first, last)
        account = google.holding(SCOPE)
        return Success(0) if account.nil?

        Success(first.step(last, CHUNK_DAYS).sum { sync(account, it, [it + CHUNK_DAYS - 1, last].min) })
      rescue Google::Error => e
        Failure([:google_health_failed, e.message])
      end

      def workout(point)
        exercise = point["exercise"]

        {
          google_id: point["name"], kind: exercise["exerciseType"],
          started_at: Time.iso8601(exercise.dig("interval", "startTime")), minutes: workout_minutes(exercise),
          device: point.dig("dataSource", "device", "displayName"), **metrics(exercise.fetch("metricsSummary", {})),
        }
      end

      def workout_minutes(exercise)
        interval = exercise.fetch("interval")
        seconds = exercise["activeDuration"]&.delete_suffix("s")&.to_f

        ((seconds || (Time.iso8601(interval["endTime"]) - Time.iso8601(interval["startTime"]))) / 60).round
      end

      def workouts(account, first, last)
        field = "exercise.interval.civil_start_time"
        filter = %(#{field} >= "#{first.iso8601}" AND #{field} < "#{(last + 1).iso8601}")

        points(account, "exercise", filter).map { workout(it) }
      end

      def zone_minutes(account, first, last)
        rollup(account, "active-zone-minutes", first, last) do |point|
          zones = point["activeZoneMinutes"]
          { active_zone_minutes: zones && ZONES.sum { zones[it].to_i } }
        end
      end
    end
  end
end
