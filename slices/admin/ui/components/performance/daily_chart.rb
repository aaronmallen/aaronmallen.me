# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Performance
        class DailyChart < Component
          LABELS = 3
          MIDDLE = 2

          prop :days, Blog::Types::Array.of(Blog::Types::Hash)
          prop :note, Blog::Types::String
          prop :title, Blog::Types::String

          def view_template
            Card(title: @title) do |card|
              card.side { key }
              timed.empty? ? Empty { t(".empty") } : chart
            end
          end

          private

          def bar(day)
            div(class: "perf-bar perf-fill-95", style: "height: #{share(day[:p95], peak)}%") do
              div(class: "perf-fill-50", style: "height: #{share(day[:p50], day[:p95])}%")
            end
          end

          def chart
            div(class: "perf-chart", role: "img",
                aria: { label: t(".label", title: @title, peak: ms(peak), day: worst) }) do
              div(class: "perf-chart-y") { [ms(peak), count(peak / MIDDLE), "0"].each { |mark| span { mark } } }
              plot
            end
            div(class: "perf-chart-dates") { labels.each { |day| span { short(day) } } }
          end

          def column(day)
            div(class: "perf-col") do
              bar(day) if day[:p95]
              span(class: "chart-tip") { tip(day) }
            end
          end

          def count(value) = Blog::Helpers::Figures.count(value.round)

          def key
            span(class: "perf-key perf-key-50") { t(".p50") }
            span(class: "perf-key perf-key-95") { t(".p95") }
            span(class: "perf-key-note") { @note }
          end

          def labels
            found = @days.map { it[:day] }

            found.size < LABELS ? found : [found.first, found[found.size / MIDDLE], found.last]
          end

          def median = timed.map { it[:p95] }.sort[timed.size / MIDDLE]

          def ms(value) = t(".ms", value: count(value))

          def peak = @peak ||= timed.map { it[:p95] }.max

          def plot
            div(class: "perf-chart-plot") do
              span(class: "perf-median", style: "bottom: #{share(median, peak)}%") do
                em { t(".median", value: ms(median)) }
              end
              @days.each { column(it) }
            end
          end

          def share(part, whole) = Blog::Helpers::Figures.share(part, whole)

          def short(day) = l(day, format: :short)

          def timed = @timed ||= @days.select { it[:p95] }

          def times(day)
            return [] unless day[:p95]

            [t(".p50_value", value: ms(day[:p50])), t(".p95_value", value: ms(day[:p95]))]
          end

          def tip(day)
            dotted(short(day[:day]), *times(day), t(".requests", count: day[:count], formatted: count(day[:count])))
          end

          def worst = short(timed.max_by { it[:p95] }[:day])
        end
      end
    end
  end
end
