# frozen_string_literal: true

module Health
  module Structs
    Day = Data.define(
      :day, :minutes_asleep, :bed_at, :woke_at, :resting_heart_rate, :hrv, :steps, :active_zone_minutes,
      :focus_minutes, :commits, :late_commits, :tasks_done, :pull_requests_opened, :pull_requests_merged,
      :journal_entries, :first_active_at, :last_active_at,
    ) do
      def health? = [minutes_asleep, resting_heart_rate, hrv, steps, active_zone_minutes].any?

      def short_night? = !minutes_asleep.nil? && minutes_asleep < Patterns::SHORT_NIGHT

      def weekday? = !(day.saturday? || day.sunday?)
    end
  end
end
