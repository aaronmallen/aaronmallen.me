# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Trend < Component
          prop :days, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            div(class: "jobs-trend") do
              div { today }
              bars
            end
          end

          private

          def bar(day, peak)
            today = day.equal?(@days.last)

            div(class: ["jobs-bar", ("jobs-bar-today" if today)]) do
              i(class: "jobs-bar-done", style: height(day[:processed] - day[:failed], peak))
              i(class: "jobs-bar-failed", style: height(day[:failed], peak)) if day[:failed].positive?
              span { today ? t(".today") : weekday(day) }
            end
          end

          def bars
            peak = @days.map { it[:processed] }.max
            label = t(".bars", days: @days.map { said(it) }.join("; "))

            div(class: "jobs-bars", role: "img", aria: { label: }) { @days.each { bar(it, peak) } }
          end

          def count(number) = Blog::Helpers::Figures.count(number)

          def height(part, whole) = "height: #{Blog::Helpers::Figures.share(part, whole)}%"

          def said(day)
            t(".day", day: weekday(day), processed: count(day[:processed]), failed: count(day[:failed]))
          end

          def tally(number, label)
            plain count(number)
            whitespace
            span { label }
          end

          def today
            found = @days.last

            p(class: "jobs-today") { t(".today") }
            p(class: "jobs-big") { tally(found[:processed], t(".processed")) }
            p(class: ["jobs-big jobs-big-small", ("jobs-failed" if found[:failed].positive?)]) do
              tally(found[:failed], t(".failed"))
            end
          end

          def weekday(day) = l(day[:day], format: "%a")
        end
      end
    end
  end
end
