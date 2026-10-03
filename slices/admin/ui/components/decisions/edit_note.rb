# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class EditNote < Component
          FIELD = :note
          HEIGHT = "120px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :name, Blog::Types::String
          prop :scope, Blog::Types::String
          prop :value, Blog::Types::String
          prop :errors, Blog::Types::Hash

          def view_template
            Card(label: t(".label"), data: { edit_note: "" }) do
              div(class: "form-stack", data: { edit_note_field: "" }) do
                MarkdownEditor(**FieldError.control_attributes(FIELD, @errors, @scope), **editor_props)
                FieldError(field: FIELD, errors: @errors, scope: @scope)
                Hint { t(".hint") }
              end
            end
            EditNoteDialog(title_id: "#{@scope}-note-dialog-title")
          end

          private

          def editor_props
            { name: @name, value: @value, height: HEIGHT, renderer: RENDERER, label: t(".label"),
              placeholder: t(".placeholder") }
          end
        end
      end
    end
  end
end
