# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class FeedCard < Component
          HEIGHT = 100
          LABELS = 3
          MIDDLE = 2
          STEP = 10

          prop :aggregators, Blog::Types::Array.of(Blog::Types::Hash)
          prop :days, Blog::Types::Array.of(Blog::Types::Hash)
          prop :latest, Blog::Types::Integer

          def view_template
            Card(title: t(".title")) do |card|
              card.side { span(class: "chart-peak") { t(".latest", count: Blog::Helpers::Figures.count(@latest)) } }

              chart
              readings
              div(class: "feed-aggregators") { Meters(color: :blue, empty: t(".no_aggregators"), rows: aggregators) }
            end
          end

          private

          def aggregators = @aggregators.map { { count: it[:subscribers], label: it[:aggregator] } }

          def chart
            div(class: "chart sm") do
              curve
              div(class: "curve-dates") { labels.each { |day| span { short(day) } } }
            end
          end

          def counts = @days.map { it[:subscribers] }

          def curve
            svg(class: "curve", viewBox: "0 0 #{x(@days.size)} #{HEIGHT}", preserveAspectRatio: "none",
                aria_hidden: "true") do |s|
              s.polyline(class: "curve-post", points:)
            end
          end

          def labels
            found = @days.map { it[:day] }

            found.size < LABELS ? found : [found.first, found[found.size / MIDDLE], found.last]
          end

          def peak = @peak ||= counts.max.to_f

          def points
            placed = counts.each_with_index.map { |count, index| "#{x(index + 1)},#{y(count)}" }

            (placed.one? ? placed * 2 : placed).join(" ")
          end

          def readings
            table(class: "sr-only") do
              caption { t(".caption", count: @days.size) }
              thead { tr { %w[.day .subscribers].each { |key| th(scope: "col") { t(key) } } } }
              tbody { @days.each { row(it) } }
            end
          end

          def row(point)
            tr do
              th(scope: "row") { short(point[:day]) }
              td { Blog::Helpers::Figures.count(point[:subscribers]) }
            end
          end

          def short(day) = l(day, format: :short)

          def x(day) = (day - 1) * STEP

          def y(count) = peak.zero? ? HEIGHT : (HEIGHT - (count * HEIGHT / peak)).round(1)
        end
      end
    end
  end
end
