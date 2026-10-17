# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class Line < Component
          prop :href, Blog::Types::String
          prop :text, Blog::Types::String
          prop :day, Blog::Types::Date.optional, default: nil
          prop :format, Blog::Types::Symbol, default: :short
          prop :menu, Blog::Types::String.optional, default: nil

          def view_template
            a(class: "review-line", href: @href, data: { menu: @menu }) do
              dated if @day
              plain Helpers::Short.title(@text.lines.first.to_s.strip)
            end
          end

          private

          def dated
            span(class: "meta") { l(@day, format: @format) }
            whitespace
          end
        end
      end
    end
  end
end
