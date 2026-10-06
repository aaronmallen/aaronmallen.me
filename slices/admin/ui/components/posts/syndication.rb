# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Syndication < Component
          FIELD = :syndication_body
          TARGETS = "post[syndication_targets][]"

          prop :body, Blog::Types::String
          prop :counts, Blog::Types::Hash
          prop :enabled, Blog::Types::Bool
          prop :errors, Blog::Types::Hash
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :people, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :preview, Blog::Types::String

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack", data: { syndication: path(:admin_preview_post_syndication) }) do
                Toggle(label: t(".queue"), name: "post[syndication_enabled]", checked: @enabled)
                input(type: "hidden", name: TARGETS, value: Blog::Constants::EMPTY_STRING)
                Social::Targets(networks: @networks, name: TARGETS)
                text_field
                Hint { t(".hint") }
              end
            end
          end

          private

          def body_attributes
            {
              class: "compose-body",
              name: "post[syndication_body]",
              placeholder: @preview.empty? ? t(".placeholder") : @preview,
              data: { social_body: "", social_placeholder: t(".placeholder"), social_preview: @preview },
            }
          end

          def text_field
            Field(label: t(".text"), name: FIELD, errors: @errors, error: FieldError) do |control|
              Textarea(**control, value: @body, **body_attributes)
              Social::Counts(counts: @counts, networks: @networks)
              Social::Directory(people: @people)
            end
          end
        end
      end
    end
  end
end
