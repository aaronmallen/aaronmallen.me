# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Tag < Component
        PREFIX = "#"

        prop :tag, Blog::Types::Instance(ROM::Struct)
        prop :link, Blog::Types::Bool, default: true

        def view_template
          return span(class: classes) { PREFIX + @tag.name } unless @link

          a(class: classes, href: path(:admin_tag, name: @tag.name)) { PREFIX + @tag.name }
        end

        private

        def classes = ["tag", Blog::UI::Components::Pill.for_tag_color(@tag.color)&.to_s]
      end
    end
  end
end
