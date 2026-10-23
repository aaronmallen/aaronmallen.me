# frozen_string_literal: true

health = Health::Slice
first = Seeds.today - 28
last = Seeds.today - 1
return if health["repos.health_queries"].days(from: first, to: last).any?

random = Random.new(1946)
days = (first..last).map do |day|
  woke_at = Blog::TimeZone.local_time(*Seeds.date_parts(day), 6, random.rand(50))
  asleep = random.rand(330..480)

  {
    day:, minutes_asleep: asleep, bed_at: woke_at - ((asleep + random.rand(15..40)) * 60), woke_at:,
    resting_heart_rate: random.rand(52..61), hrv: random.rand(38.0..62.0).round(1), steps: random.rand(3_000..14_000),
    active_zone_minutes: random.rand(0..60),
  }
end

workouts = [[2, "running", 32, 5_200.0], [5, "walking", 48, 3_900.0], [9, "biking", 61, 18_400.0],
            [13, "strength_training", 40, nil], [16, "running", 29, 4_800.0]].map do |days_ago, kind, minutes, meters|
  {
    google_id: "workout-#{days_ago}", kind:, started_at: Seeds.ago(days_ago, hour: 7), minutes:,
    distance_meters: meters, average_heart_rate: random.rand(110..150), zone_minutes: minutes / 2,
    kcal: minutes * 9, device: "Example Watch",
  }
end

health["repos.health_mutations"].store(days:, workouts:, window: first..last)
