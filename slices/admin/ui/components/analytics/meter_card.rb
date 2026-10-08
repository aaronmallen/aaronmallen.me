# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class MeterCard < Component
          COLORS = %i[blue pink violet].freeze

          prop :color, Blog::Types::Symbol.enum(*COLORS)
          prop :empty, Blog::Types::String
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :title, Blog::Types::String

          def view_template
            Card(title: @title) do
              next Empty { @empty } if @rows.empty?

              @rows.each { row(it) }
            end
          end

          private

          def bar(entry)
            span(class: ["meter", @color.to_s]) do
              span(class: "meter-fill", style: "width: #{Blog::Helpers::Figures.share(entry[:count].to_i, top)}%")
            end
          end

          def row(entry)
            div(class: "meter-row") do
              span(class: "meter-name") { entry[:label] }
              bar(entry)
              span(class: "meter-count") { Blog::Helpers::Figures.count(entry[:count]) if entry[:count] }
            end
          end

          def top = @top ||= @rows.filter_map { it[:count] }.max.to_i
        end
      end
    end
  end
end
