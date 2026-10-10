# frozen_string_literal: true

module Admin
  module UI
    module Components
      class EditNote < Component
        HEIGHT = "120px"

        prop :field, Blog::Types::Symbol
        prop :name, Blog::Types::String
        prop :value, Blog::Types::String
        prop :errors, Blog::Types::Hash
        prop :error, Field::ERROR
        prop :scope, Blog::Types::String.optional, default: nil
        prop :renderer, Blog::Types::MarkdownRenderer
        prop :hint, Blog::Types::String
        prop :placeholder, Blog::Types::String

        def view_template
          Card(label: t(".label"), data: { edit_note: "" }) do
            div(class: "form-stack", data: { edit_note_field: "" }) do
              MarkdownEditor(field: @field, errors: @errors, error: @error, scope:, **editor_props)
              Hint { @hint }
            end
          end
          EditNoteDialog(title_id: "#{scope}-note-dialog-title")
        end

        private

        def editor_props
          { name: @name, value: @value, height: HEIGHT, renderer: @renderer, label: t(".label"),
            placeholder: @placeholder }
        end

        def scope = @scope || @error::SCOPE
      end
    end
  end
end
