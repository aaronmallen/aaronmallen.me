# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Health
        class Grid < Component
          FLOOR = 6
          FULL = 100
          HEALTH = [
            { name: ".asleep", tone: "vi", min: 240, max: 540, value: :minutes_asleep, unit: :minutes,
              flag: :short_night? },
            { name: ".hrv", tone: "gr", min: 20, max: 60, value: :hrv, unit: ".ms", flag: :low_hrv? },
            { name: ".resting", tone: "or", min: 45, max: 65, value: :resting_heart_rate, unit: ".bpm",
              flag: :high_resting? },
            { name: ".exercise", tone: "bl", min: 0, max: 120, value: :exercise, unit: :minutes },
          ].freeze
          WORK = [
            { name: ".focused", min: 0, max: 360, value: :focus_minutes, unit: :minutes },
            { name: ".commits", min: 0, max: 12, value: :commits, unit: :count },
            { name: ".late", tone: "pk", min: 0, max: 4, value: :late_commits, unit: ".late_count", flag: :late? },
          ].freeze

          prop :day, Blog::Types::Date
          prop :report, Blog::Types::Instance(::Health::Structs::Report)
          prop :span, Blog::Types::HealthSpan

          def view_template
            div(class: "health-grid", role: "group", aria: { label: t(".label") }) do
              HEALTH.each { row(**it) }
              p(class: "health-grid-sep") { t(".work") }
              WORK.each { row(**it) }
              axis
            end
          end

          private

          def axis
            days = @report.days
            div(class: "health-grid-axis", aria: { hidden: true }) do
              span { l(days.first.day, format: :short) }
              span { l(days[days.size / 2].day, format: :short) }
              span { t(".today") }
            end
          end

          def bar(value, min, max)
            return 0 if value.nil? || value <= min

            ((value - min) * FULL / (max - min)).round.clamp(FLOOR, FULL)
          end

          def cell(day, name:, min:, max:, value:, unit:, flag: nil)
            found = value(day, value)
            a(
              class: ["health-grid-day", ("we" unless day.weekday?), ("on" if day.day == @day)],
              href: path(:admin_health, span: @span, day: day.day.iso8601), tabindex: -1,
              title: "#{l(day.day, format: :short)} · #{t(name)} #{figure(unit, found)}",
            ) do
              i(class: ("lo" if flag && flagged?(day, flag)), style: "height: #{bar(found, min, max)}%")
            end
          end

          def exercise = @exercise ||= @report.workouts.group_by { Blog::TimeZone.local(it.started_at).to_date }

          def figure(unit, value)
            return t(".none") if value.nil?

            case unit
              when :minutes then Blog::Helpers::Figures.minutes(value)
              when :count then value.to_s
              else t(unit, count: value.round)
            end
          end

          def flagged?(day, flag)
            case flag
              when :short_night? then day.short_night?
              when :late? then day.late_commits.positive?
              else @report.baseline.public_send(flag, day)
            end
          end

          def row(name:, tone: nil, **row)
            span(class: "health-grid-label") { t(name) }
            div(class: ["health-grid-row", tone], aria: { hidden: true }) do
              @report.days.each { cell(it, name:, **row) }
            end
          end

          def value(day, name)
            return exercise.fetch(day.day, Blog::Constants::EMPTY_ARRAY).sum(&:minutes) if name == :exercise

            day.public_send(name)
          end
        end
      end
    end
  end
end
