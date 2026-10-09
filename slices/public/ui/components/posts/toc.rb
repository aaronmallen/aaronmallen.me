# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Toc < Component
          HEADINGS = Blog::Types::Array.of(Blog::Types::Hash.schema(id: Blog::Types::String, text: Blog::Types::String))
          MINIMUM = 3

          prop :headings, HEADINGS

          def view_template
            return if @headings.size < MINIMUM

            aside(class: "toc", aria: { label: t(".label") }) do
              h2(class: "kicker") { t(".label") }
              ol do
                @headings.each { |heading| li { a(href: "##{heading[:id]}") { heading[:text] } } }
              end
            end
          end
        end
      end
    end
  end
end
