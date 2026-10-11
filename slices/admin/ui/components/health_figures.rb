# frozen_string_literal: true

module Admin
  module UI
    module Components
      class HealthFigures < Component
        SLEEP = %i[minutes_asleep hrv resting_heart_rate].freeze

        def self.slept?(day) = !day.nil? && SLEEP.any? { day[it] }

        prop :day, Blog::Types::Instance(ROM::Struct)
        prop :steps, Blog::Types::Bool, default: false
        prop :stacked, Blog::Types::Bool, default: false

        def view_template
          return plain(dotted(asleep, hrv, resting_heart_rate, steps)) unless @stacked

          [asleep, dotted(hrv, resting_heart_rate), steps].reject { it.to_s.empty? }.each { |line| span { line } }
        end

        private

        def asleep
          minutes = @day.minutes_asleep
          t(".asleep", span: Blog::Helpers::Figures.hours(minutes * Blog::Helpers::Figures::MINUTE)) if minutes
        end

        def hrv = (t(".hrv", value: @day.hrv.round) if @day.hrv)

        def resting_heart_rate = (t(".resting_heart_rate", value: @day.resting_heart_rate) if @day.resting_heart_rate)

        def steps
          count = @day.steps
          t(".steps", count:, formatted: Blog::Helpers::Figures.count(count)) if @steps && count
        end
      end
    end
  end
end
