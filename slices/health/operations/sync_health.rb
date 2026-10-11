# frozen_string_literal: true

module Health
  module Operations
    class SyncHealth < Blog::Operation
      CHUNK_DAYS = 90
      DATA_TYPES = "users/me/dataTypes"
      EMPTY_DAY = {
        minutes_asleep: nil, bed_at: nil, woke_at: nil, resting_heart_rate: nil, hrv: nil, steps: nil,
        active_zone_minutes: nil,
      }.freeze
      READERS = %i[nights resting_heart_rates hrvs step_counts zone_minutes].freeze
      ZONES = %w[sumInFatBurnHeartZone sumInCardioHeartZone sumInPeakHeartZone].freeze

      include Deps["google.client", health_mutations: "repos.health_mutations"]

      def call(first, last) = step synced(first, last)

      private

      def civil(date) = { date: { year: date.year, month: date.month, day: date.day } }

      def date(value) = Date.new(*value.values_at("year", "month", "day"))

      def days(first, last)
        found = READERS.map { send(it, first, last) }

        (first..last).filter_map do |day|
          row = found.map { it.fetch(day, {}) }.reduce(:merge)
          { **EMPTY_DAY, day:, **row } unless row.compact.empty?
        end
      end

      def hrvs(first, last)
        summaries("daily-heart-rate-variability", "dailyHeartRateVariability", first, last) do |summary|
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

      def nights(first, last)
        bounds = Blog::TimeZone.day_bounds(first, last).map { %("#{it.utc.iso8601}") }
        filter = "sleep.interval.end_time >= #{bounds[0]} AND sleep.interval.end_time < #{bounds[1]}"
        nights = points("sleep", filter).map { it["sleep"] }

        nights.group_by { Blog::TimeZone.today(Time.iso8601(it.dig("interval", "endTime"))) }
              .transform_values { night(it) }
      end

      def points(type, filter, **params)
        page = client.get("#{DATA_TYPES}/#{type}/dataPoints", filter:, **params)
        rows = page.fetch("dataPoints", [])
        token = page["nextPageToken"].to_s
        token.empty? ? rows : rows + points(type, filter, **params, page_token: token)
      end

      def resting_heart_rates(first, last)
        summaries("daily-resting-heart-rate", "dailyRestingHeartRate", first, last) do |summary|
          { resting_heart_rate: summary["beatsPerMinute"]&.to_i }
        end
      end

      def rollup(type, first, last)
        body = { range: { start: civil(first), end: civil(last + 1) }, windowSizeDays: 1 }
        rows = client.post("#{DATA_TYPES}/#{type}/dataPoints:dailyRollUp", body).fetch("rollupDataPoints", [])

        rows.to_h { [date(it.dig("civilStartTime", "date")), yield(it)] }
      end

      def step_counts(first, last) = rollup("steps", first, last) { { steps: it.dig("steps", "countSum")&.to_i } }

      def summaries(type, field, first, last)
        filter = %(#{field}.date >= "#{first.iso8601}" AND #{field}.date < "#{(last + 1).iso8601}")

        points(type, filter).to_h { [date(it.dig(field, "date")), yield(it[field])] }
      end

      def sync(first, last) = health_mutations.store(days: days(first, last), workouts: workouts(first, last))

      def synced(first, last)
        return Success(0) unless client.connected?

        Success(first.step(last, CHUNK_DAYS).sum { sync(it, [it + CHUNK_DAYS - 1, last].min) })
      rescue Error => e
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

      def workouts(first, last)
        field = "exercise.interval.civil_start_time"
        filter = %(#{field} >= "#{first.iso8601}" AND #{field} < "#{(last + 1).iso8601}")

        points("exercise", filter).map { workout(it) }
      end

      def zone_minutes(first, last)
        rollup("active-zone-minutes", first, last) do |point|
          zones = point["activeZoneMinutes"]
          { active_zone_minutes: zones && ZONES.sum { zones[it].to_i } }
        end
      end
    end
  end
end
