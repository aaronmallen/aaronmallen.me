# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class WorkedCard < Component
          prop :worked, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Integer)

          def view_template
            Card(title: t(".title"), id: "review-worked") do |card|
              card.side { span(class: "review-total") { Blog::Figures.hours(@worked.values.sum) } }

              @worked.each { |day, seconds| row(day, seconds) }
            end
          end

          private

          def row(day, seconds)
            div(class: "meter-row") do
              span(class: "meter-name") { t(".day", weekday: l(day, format: :day_name), date: l(day, format: :short)) }
              span(class: "meter blue") do
                span(class: "meter-fill", style: "width: #{Blog::Figures.share(seconds, top)}%")
              end
              span(class: "meter-count") { Blog::Figures.hours(seconds) }
            end
          end

          def top = @top ||= @worked.values.max.to_i
        end
      end
    end
  end
end
