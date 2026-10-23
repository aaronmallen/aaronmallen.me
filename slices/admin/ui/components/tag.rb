# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Tag < Component
        PREFIX = "#"

        prop :tag, Blog::Types::Instance(ROM::Struct)
        prop :link, Blog::Types::Bool, default: true
        prop :project_key, Blog::Types::String.optional, default: nil

        def view_template
          return span(class: classes) { PREFIX + @tag.name } unless @link

          a(class: classes, href:) { PREFIX + @tag.name }
        end

        private

        def classes = ["tag", Blog::UI::Components::Pill.for_tag_color(@tag.color)&.to_s]

        def href
          key = @project_key || @tag.to_h[:project_key]
          return path(:admin_tag, name: @tag.name) unless key

          path(:admin_project_tag, key:, name: @tag.name)
        end
      end
    end
  end
end
