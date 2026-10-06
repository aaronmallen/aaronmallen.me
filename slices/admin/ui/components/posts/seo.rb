# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Seo < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack") do
                og_title_field
                og_image_url_field
                canonical_url_field
              end
            end
          end

          private

          def canonical_url_field
            Field(label: t(".canonical_url"), name: :canonical_url, errors: @errors, error: FieldError) do |control|
              url_input(control, :canonical_url, ".canonical_url_placeholder")
              Hint { t(".canonical_url_note") }
            end
          end

          def og_image_url_field
            Field(label: t(".og_image_url"), name: :og_image_url, errors: @errors, error: FieldError) do |control|
              url_input(control, :og_image_url, ".og_image_url_placeholder")
              Hint { t(".og_image_url_note") }
            end
          end

          def og_title_field
            Field(label: t(".og_title"), name: :og_title, errors: @errors, error: FieldError) do |control|
              Input(
                **control,
                name: "post[og_title]",
                value: @values[:og_title],
                placeholder: placeholder,
              )
              Hint { t(".og_title_note") }
            end
          end

          def placeholder
            given = @values[:title].to_s.strip

            given.empty? ? t(".og_title_placeholder") : given
          end

          def url_input(control, name, placeholder_key)
            Input(
              **control,
              type: "url",
              name: "post[#{name}]",
              value: @values[name],
              placeholder: t(placeholder_key),
            )
          end
        end
      end
    end
  end
end
