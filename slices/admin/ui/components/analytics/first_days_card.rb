# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class FirstDaysCard < Component
          HEADINGS = %w[.day_heading .post .median].freeze
          HEIGHT = 100
          MEDIAN = "%g"
          STEP = 10

          prop :days, Blog::Types::Array.of(Blog::Types::Integer)
          prop :median, Blog::Types::Array.of(Blog::Types::Integer | Blog::Types::Float)
          prop :span, Blog::Types::Integer

          def view_template
            Card(title: t(".title", count: @span)) do |card|
              next Empty { t(".empty") } if @days.empty?

              card.side { key }

              div(class: "chart") do
                curves
                div(class: "chart-dates") { labels.each { |day| span { t(".day", day:) } } }
              end
              readings
            end
          end

          private

          def cell(value) = td { value }

          def curves
            svg(class: "curve", viewBox: "0 0 #{x(@span)} #{HEIGHT}", preserveAspectRatio: "none",
                aria_hidden: "true") do |s|
              s.polyline(class: "curve-median", points: points(@median))
              s.polyline(class: "curve-post", points: points(@days))
            end
          end

          def key
            span(class: "curve-key curve-key-post") { t(".post") }
            span(class: "curve-key curve-key-median") { t(".median") }
          end

          def labels = [1, (@span + 1) / 2, @span]

          def median_text(value) = format(MEDIAN, value.round(1))

          def peak = @peak ||= [*@days, *@median].max.to_f

          def points(counts)
            placed = counts.each_with_index.map { |count, index| "#{x(index + 1)},#{y(count)}" }

            (placed.one? ? placed * 2 : placed).join(" ")
          end

          def readings
            table(class: "sr-only") do
              caption { t(".caption", count: @span) }
              thead { tr { HEADINGS.each { |key| th(scope: "col") { t(key) } } } }
              tbody { (1..[@days.size, @median.size].max).each { row(it) } }
            end
          end

          def row(day)
            tr do
              th(scope: "row") { day.to_s }
              cell(@days[day - 1]&.then { Blog::Figures.count(it) })
              cell(@median[day - 1]&.then { median_text(it) })
            end
          end

          def x(day) = (day - 1) * STEP

          def y(count) = peak.zero? ? HEIGHT : (HEIGHT - (count * HEIGHT / peak)).round(1)
        end
      end
    end
  end
end
