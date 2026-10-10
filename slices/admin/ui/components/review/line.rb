# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class Line < Component
          TEXT_LIMIT = 80

          prop :href, Blog::Types::String
          prop :text, Blog::Types::String
          prop :day, Blog::Types::Date.optional, default: nil

          def view_template
            a(class: "review-line", href: @href) do
              dated if @day
              plain Blog::Helpers::Truncation.cut(@text.lines.first.to_s.strip, keep: TEXT_LIMIT)
            end
          end

          private

          def dated
            span(class: "meta") { l(@day, format: :short) }
            whitespace
          end
        end
      end
    end
  end
end
