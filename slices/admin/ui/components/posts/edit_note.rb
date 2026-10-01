# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditNote < Component
          FIELD = :edit_note
          HEIGHT = "120px"

          prop :value, Blog::Types::String
          prop :errors, Blog::Types::Hash

          def view_template
            Card(label: t(".label")) do
              div(class: "form-stack") do
                MarkdownEditor(**FieldError.control_attributes(FIELD, @errors), **editor_props)
                FieldError(field: FIELD, errors: @errors)
                Hint { t(".hint") }
              end
            end
          end

          private

          def editor_props
            {
              name: "post[#{FIELD}]", value: @value, height: HEIGHT, renderer: "posts", label: t(".label"),
              placeholder: t(".placeholder"),
            }
          end
        end
      end
    end
  end
end
