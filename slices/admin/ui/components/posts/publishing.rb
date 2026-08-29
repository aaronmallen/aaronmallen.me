# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Publishing < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :published, Blog::Types::Bool
          prop :scheduling, Blog::Types::Bool

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack") do
                slug_field
                tags_field
                publish_at_field
                hints unless @published
              end
            end
          end

          private

          def control(field) = FieldError.control_attributes(field, @errors)

          def field(name, label_key, &)
            Field(label: t(label_key), id: "post-#{name}") do
              yield
              FieldError(field: name, errors: @errors)
            end
          end

          def hints
            Hint(data: { editor_now: "" }, hidden: @scheduling) { t(".hint_now") }
            Hint(data: { editor_later: "" }, hidden: !@scheduling) { t(".hint_later") }
          end

          def publish_at_field
            field(:publish_at, ".publish_at") do
              Input(
                **control(:publish_at),
                type: "datetime-local",
                name: "post[publish_at]",
                value: @values[:publish_at],
                readonly: @published,
                data: { editor_publish_at: "" },
              )
            end
          end

          def slug_field
            field(:slug, ".slug") do
              Input(
                **control(:slug),
                name: "post[slug]",
                value: @values[:slug],
                placeholder: ::Posts::PostSlug.from_title(@values[:title]),
                readonly: @published,
                data: { editor_slug: "" },
              )
            end
          end

          def tags_field
            field(:tags, ".tags") do
              Input(**control(:tags), name: "post[tags]", value: @values[:tags], placeholder: t(".tags_placeholder"))
            end
          end
        end
      end
    end
  end
end
