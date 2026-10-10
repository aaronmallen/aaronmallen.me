# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class Curve < Component
          HEIGHT = 100
          STEP = 10

          prop :lines, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Integer | Blog::Types::Float))
          prop :span, Blog::Types::Integer

          def view_template
            svg(class: "curve", viewBox: "0 0 #{x(@span)} #{HEIGHT}", preserveAspectRatio: "none",
                aria_hidden: "true") do |s|
              @lines.each { |name, counts| s.polyline(class: name, points: points(counts)) }
            end
          end

          private

          def peak = @peak ||= @lines.values.flatten.max.to_f

          def points(counts)
            placed = counts.each_with_index.map { |count, index| "#{x(index + 1)},#{y(count)}" }

            (placed.one? ? placed * 2 : placed).join(" ")
          end

          def x(day) = (day - 1) * STEP

          def y(count) = peak.zero? ? HEIGHT : (HEIGHT - (count * HEIGHT / peak)).round(1)
        end
      end
    end
  end
end
