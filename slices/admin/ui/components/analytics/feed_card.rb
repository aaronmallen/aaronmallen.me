# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class FeedCard < Component
          LABELS = 3
          MIDDLE = 2

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
              Curve(span: @days.size, lines: { "curve-post" => counts })
              div(class: "curve-dates") { labels.each { |day| span { short(day) } } }
            end
          end

          def counts = @days.map { it[:subscribers] }

          def labels
            found = @days.map { it[:day] }

            found.size < LABELS ? found : [found.first, found[found.size / MIDDLE], found.last]
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
        end
      end
    end
  end
end
