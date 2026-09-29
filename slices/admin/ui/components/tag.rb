# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Tag < Component
        PREFIX = "#"

        prop :tag, Blog::Types::Instance(ROM::Struct)
        prop :href, Blog::Types::String.optional, default: nil

        def view_template
          return span(class: classes) { label } if @href.nil?

          a(class: classes, href: @href) { label }
        end

        private

        def classes = ["tag", Blog::UI::Components::Pill.for_tag_color(@tag.color)&.to_s]

        def label = PREFIX + @tag.name
      end
    end
  end
end
