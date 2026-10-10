# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class FirstDaysCard < Component
          HEADINGS = %w[.day_heading .post .median].freeze
          MEDIAN = "%g"

          prop :days, Blog::Types::Array.of(Blog::Types::Integer)
          prop :median, Blog::Types::Array.of(Blog::Types::Integer | Blog::Types::Float)
          prop :span, Blog::Types::Integer

          def view_template
            Card(title: t(".title", count: @span)) do |card|
              next Empty { t(".empty") } if @days.empty?

              card.side { key }

              div(class: "chart") do
                Curve(span: @span, lines: { "curve-median" => @median, "curve-post" => @days })
                div(class: "chart-dates") { labels.each { |day| span { t(".day", day:) } } }
              end
              readings
            end
          end

          private

          def cell(value) = td { value }

          def key
            span(class: "curve-key curve-key-post") { t(".post") }
            span(class: "curve-key curve-key-median") { t(".median") }
          end

          def labels = [1, (@span + 1) / 2, @span]

          def median_text(value) = format(MEDIAN, value.round(1))

          def readings
            div(class: "sr-only") do
              table do
                caption { t(".caption", count: @span) }
                thead { tr { HEADINGS.each { |key| th(scope: "col") { t(key) } } } }
                tbody { (1..[@days.size, @median.size].max).each { row(it) } }
              end
            end
          end

          def row(day)
            tr do
              th(scope: "row") { day.to_s }
              cell(@days[day - 1]&.then { Blog::Helpers::Figures.count(it) })
              cell(@median[day - 1]&.then { median_text(it) })
            end
          end
        end
      end
    end
  end
end
