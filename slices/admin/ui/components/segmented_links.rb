# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SegmentedLinks < Component
        ITEM = Blog::Types::Hash.schema(
          text: Blog::Types::String,
          href?: Blog::Types::String,
          current?: Blog::Types::Bool,
          data?: Blog::Types::Hash,
          disabled?: Blog::Types::Bool,
          icon?: Blog::Types::String,
          rel?: Blog::Types::String,
        )

        prop :label, Blog::Types::String
        prop :items, Blog::Types::Array.of(ITEM)

        def view_template
          nav(class: "seg", aria: { label: @label }) { @items.each { link(**it) } }
        end

        private

        def content(text, icon)
          return plain(text) unless icon

          Icon(["fa-solid", icon])
          span(class: "sr-only") { text }
        end

        def link(text:, href: nil, current: false, data: nil, disabled: false, icon: nil, rel: nil)
          attributes = {
            class: ["seg-option", ("current" if current)],
            aria: { current: ("page" if current), disabled: (true if disabled) },
            data:,
          }
          return span(**attributes) { content(text, icon) } if disabled || href.nil?

          a(href:, rel:, **attributes) { content(text, icon) }
        end
      end
    end
  end
end
