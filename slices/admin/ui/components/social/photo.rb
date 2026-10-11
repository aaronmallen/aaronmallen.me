# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Photo < Component
          FIELD = "social[photos][]"

          prop :part, Blog::Types::Integer.optional, default: nil
          prop :key, Blog::Types::String, default: Blog::Constants::EMPTY_STRING
          prop :alt, Blog::Types::String, default: Blog::Constants::EMPTY_STRING

          def view_template
            li(class: "compose-photo", data: { social_photo: "" }) do
              img(class: "compose-photo-img", src: src, alt: "", data: { social_photo_img: "" })
              input(type: "hidden", name: "#{FIELD}[part]", value: @part, data: { social_photo_part: "" })
              input(type: "hidden", name: "#{FIELD}[key]", value: @key, data: { social_photo_key: "" })
              alt_field
              tools
            end
          end

          private

          def alt_field
            label(class: "compose-photo-alt") do
              span(class: "compose-photo-alt-label") { t(".alt") }
              Textarea(value: @alt, name: "#{FIELD}[alt]", rows: 2, data: { social_photo_alt: "" })
            end
          end

          def src = @key.empty? ? nil : "#{::Media::Types::PATH}#{@key}"

          def tool(icon, label, **data) = Button(variant: :gh, small: true, icon:, label:, data:)

          def tools
            div(class: "compose-photo-tools") do
              tool("fa-solid fa-arrow-left", t(".earlier"), social_photo_move: "-1")
              tool("fa-solid fa-arrow-right", t(".later"), social_photo_move: "1")
              tool("fa-solid fa-xmark", t(".remove"), social_photo_remove: "")
            end
          end
        end
      end
    end
  end
end
