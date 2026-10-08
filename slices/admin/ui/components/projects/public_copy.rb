# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class PublicCopy < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) do
              div(class: "form-stack") do
                tagline_field
                og_image_url_field
              end
            end
          end

          private

          def og_image_url_field
            Field(label: t(".og_image_url"), name: :og_image_url, errors: @errors, error: FieldError) do |control|
              Input(
                **control,
                type: "url",
                name: "project[og_image_url]",
                value: @values[:og_image_url],
                placeholder: t(".og_image_url_placeholder"),
              )
              Hint { t(".og_image_url_note") }
            end
          end

          def tagline_field
            Field(label: t(".tagline"), name: :tagline, errors: @errors, error: FieldError) do |control|
              Textarea(
                **control,
                name: "project[tagline]",
                rows: 2,
                value: @values[:tagline],
                placeholder: t(".tagline_placeholder"),
                data: { editor_tagline: "" },
              )
            end
          end
        end
      end
    end
  end
end
