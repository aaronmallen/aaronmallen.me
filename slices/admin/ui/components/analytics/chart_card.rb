# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class ChartCard < Component
          LABELS = 3
          MIDDLE = 2

          prop :series, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            Card(title: t(".title")) do |card|
              card.side { span(class: "chart-peak") { t(".peak", views: Blog::Helpers::Figures.count(peak)) } }

              div(class: "chart") do
                div(class: "chart-bars") { @series.each { bar(it) } }
                div(class: "chart-dates") { labels.each { |day| span { short(day) } } }
              end
            end
          end

          private

          def bar(point)
            div(class: "chart-bar", style: "height: #{Blog::Helpers::Figures.share(point[:views], peak)}%") do
              span(class: "chart-tip") { tip(point) }
            end
          end

          def days = @series.map { it[:day] }

          def labels
            found = days

            found.size < LABELS ? found : [found.first, found[found.size / MIDDLE], found.last]
          end

          def peak = @peak ||= @series.map { it[:views] }.max.to_i

          def short(day) = l(day, format: :short)

          def tip(point)
            t(
              ".tip",
              date: short(point[:day]),
              views: t(".views", count: point[:views], formatted: Blog::Helpers::Figures.count(point[:views])),
              visitors: t(".visitors", count: point[:visitors], formatted: Blog::Helpers::Figures.count(point[:visitors])),
            )
          end
        end
      end
    end
  end
end
