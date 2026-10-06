# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SegmentedLinks < Component
        ITEM = Blog::Types::Hash.schema(
          href: Blog::Types::String,
          text: Blog::Types::String,
          current: Blog::Types::Bool,
          data?: Blog::Types::Hash,
        )

        prop :label, Blog::Types::String
        prop :items, Blog::Types::Array.of(ITEM)

        def view_template
          nav(class: "seg", aria: { label: @label }) { @items.each { link(**it) } }
        end

        private

        def link(href:, text:, current:, data: nil)
          a(class: ["seg-option", ("current" if current)], href:, aria: { current: ("page" if current) }, data:) do
            text
          end
        end
      end
    end
  end
end
