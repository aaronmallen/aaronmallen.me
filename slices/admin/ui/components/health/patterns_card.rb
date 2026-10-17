# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Health
        class PatternsCard < Component
          PATTERNS = {
            short_nights: ["fa-moon", ".short_nights.text", ".short_nights.days"],
            morning_workouts: ["fa-person-running", ".morning_workouts.text", ".morning_workouts.days"],
            late_commits: [Blog::Helpers::RecordKinds.icon("commit"), ".late_commits.text", ".late_commits.days"],
            resting_heart_rate: ["fa-heart-pulse", ".resting_heart_rate.text", ".resting_heart_rate.days"],
          }.freeze

          DECIMAL = "%g"

          prop :patterns, Blog::Types::Instance(::Health::Structs::Patterns)
          prop :span, Blog::Types::HealthSpan

          def view_template
            Card(title: t(".title"), note: t(".span", count: @span)) do
              shown.empty? ? Empty { t(".empty") } : shown.each { pattern(*it) }
              Hint { t(".hint") }
            end
          end

          private

          def averages(pattern) = [pattern.subject, pattern.rest].map(&:averages)

          def decimal(value) = format(DECIMAL, value)

          def figures(name, pattern)
            subject, rest = averages(pattern)

            case name
              when :late_commits then nights(subject, rest)
              when :resting_heart_rate
                { bpm: decimal(subject[:resting_heart_rate]), rest_bpm: decimal(rest[:resting_heart_rate]) }
              else { focus: minutes(subject[:focus_minutes]), rest_focus: minutes(rest[:focus_minutes]) }
            end
          end

          def minutes(value) = Blog::Helpers::Figures.minutes(value.round)

          def nights(subject, rest)
            {
              asleep: minutes(subject[:minutes_asleep]), hrv: subject[:hrv].round,
              rest_asleep: minutes(rest[:minutes_asleep]), rest_hrv: rest[:hrv].round,
            }
          end

          def pattern(name, found)
            div(class: "health-pattern") do
              icon, text, days = PATTERNS.fetch(name)
              Icon(["fa-solid", icon])
              div do
                p { t(text, **figures(name, found)) }
                p(class: "meta") { t(days, days: found.subject.days, rest: found.rest.days) }
              end
            end
          end

          def shown
            @shown ||= PATTERNS.keys.filter_map do |name|
              found = @patterns.public_send(name)
              [name, found] if found && averages(found).all? { it.values.none?(&:nil?) }
            end
          end
        end
      end
    end
  end
end
