# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class Meters < Component
          COLORS = %i[blue pink violet].freeze

          prop :color, Blog::Types::Symbol.enum(*COLORS)
          prop :empty, Blog::Types::String
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :total, Blog::Types::Integer.optional, default: nil

          def view_template
            return Empty { @empty } if @rows.empty?

            @rows.each { row(it) }
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
              span(class: "meter-count") { value(entry) }
            end
          end

          def top = @top ||= @total || @rows.filter_map { it[:count] }.max.to_i

          def value(entry) = entry.fetch(:value) { Blog::Helpers::Figures.count(entry[:count]) if entry[:count] }
        end
      end
    end
  end
end
