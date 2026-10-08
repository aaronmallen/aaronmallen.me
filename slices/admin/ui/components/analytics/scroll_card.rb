# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class ScrollCard < Component
          prop :reached, Blog::Types::Array.of(Blog::Types::Hash)
          prop :views, Blog::Types::Integer

          def view_template
            Card(title: t(".title")) do
              next Empty { t(".empty") } if @views.zero?

              @reached.each { row(it) }
            end
          end

          private

          def percent(entry) = Blog::Helpers::Figures.share(entry.fetch(:views), @views)

          def row(entry)
            div(class: "meter-row") do
              span(class: "meter-name") { t(".depth", depth: entry[:depth]) }
              span(class: "meter blue") { span(class: "meter-fill", style: "width: #{percent(entry)}%") }
              span(class: "meter-count") { t(".share", percent: percent(entry)) }
            end
          end
        end
      end
    end
  end
end
