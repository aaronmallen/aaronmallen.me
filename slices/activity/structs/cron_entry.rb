# frozen_string_literal: true

module Activity
  module Structs
    class CronEntry < Data.define(:name, :description, :cron, :job, :args, :last, :next_at, :enabled)
      FAILED = Blog::Types::PerformanceJobOutcome["failed"]
      LATE = 5 * 60
      ZONE = " #{Blog::TimeZone::NAME}".freeze

      def self.enabled(states, name, entry)
        return unless states

        JSON.parse(states.fetch(name, "{}")).fetch("enabled", entry.fetch("enabled", true))
      end

      def self.from(name, entry, last:, next_times:, states:)
        new(
          name:, description: entry.fetch("description"), cron: entry.fetch("cron").delete_suffix(ZONE),
          job: entry.fetch("class"), args: entry["args"], last:, next_at: next_at(next_times, name),
          enabled: enabled(states, name, entry),
        )
      end

      def self.next_at(next_times, name)
        stamp = next_times&.[](name)

        Time.parse(stamp) if stamp
      end

      def failed? = last&.fetch(:outcome) == FAILED

      def missed?(now) = !next_at.nil? && next_at < now - LATE

      def order = [failed? ? 0 : 1, next_at.nil? ? 1 : 0, next_at.to_f, name]

      def paused? = enabled == false

      def unknown? = enabled.nil?
    end
  end
end
