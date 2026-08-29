# frozen_string_literal: true

module Blog
  module UI
    module Components
      module Posts
        class Tags < Component
          prop :tags, Blog::Types::Array.of(Blog::Types::String | Blog::Types::Instance(ROM::Struct))

          def view_template
            return if @tags.empty?

            ul(class: "post-tags", aria: { label: t(".label") }) do
              @tags.each { |tag| li { link(tag) } }
            end
          end

          private

          def hue(tag) = tag.is_a?(String) ? nil : Pill.for_tag_color(tag.color).to_s

          def link(tag)
            name = name(tag)

            a(class: ["post-tag", "p-category", hue(tag)], href: path(:tag, tag: name)) { name }
          end

          def name(tag) = tag.is_a?(String) ? tag : tag.name
        end
      end
    end
  end
end
