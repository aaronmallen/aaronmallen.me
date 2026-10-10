# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class WorkedCard < Component
          prop :worked, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Integer)
          prop :focused, Blog::Types::Bool, default: false

          def view_template
            Card(title: t(".title"), id: "review-worked") do
              next Empty { t(".empty") } if days.empty?

              totals
              next if @focused

              p(class: "review-label") { t(".longest") }
              Capped(items: days.sort_by { |day, seconds| [-seconds, day] }) { |day, seconds| row(day, seconds) }
            end
          end

          private

          def days = @days ||= @worked.select { |_, seconds| seconds.positive? }

          def hours(seconds) = Blog::Helpers::Figures.hours(seconds)

          def row(day, seconds)
            div(class: "review-bar") do
              span(class: "review-bar-name") do
                t(".day", weekday: l(day, format: :day_name), date: l(day, format: :short))
              end
              span(class: "review-bar-value") { hours(seconds) }
              span(class: "review-bar-meter") { i(style: "width: #{Blog::Helpers::Figures.share(seconds, top)}%") }
            end
          end

          def top = days.values.max

          def total = days.values.sum

          def totals
            p(class: "today-stat review-stat") do
              plain hours(total)
              next if @focused

              whitespace
              small do
                t(".average", average: hours(Blog::Helpers::Figures.average(total, days.size)),
                              days: t(".days", count: days.size))
              end
            end
          end
        end
      end
    end
  end
end
