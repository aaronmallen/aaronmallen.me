# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class PublicCopy < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            Card(label: t(".heading"), title: t(".title")) do
              div(class: "form-stack") do
                tagline_field
                og_image_url_field
              end
            end
          end

          private

          def field(name, label_key, &)
            Field(label: t(label_key), id: FieldError.id_for(name)) do
              yield
              FieldError(field: name, errors: @errors)
            end
          end

          def og_image_url_field
            field(:og_image_url, ".og_image_url") do
              Input(
                **FieldError.control_attributes(:og_image_url, @errors),
                type: "url",
                name: "project[og_image_url]",
                value: @values[:og_image_url],
                placeholder: t(".og_image_url_placeholder"),
              )
              Hint { t(".og_image_url_note") }
            end
          end

          def tagline_field
            field(:tagline, ".tagline") do
              Textarea(
                **FieldError.control_attributes(:tagline, @errors),
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
