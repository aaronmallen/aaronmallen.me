# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditNotes < Component
          FIELD = :note
          HEIGHT = "120px"

          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :noting, Blog::Types::Hash

          def self.form_id(edit_id) = "#{scope(edit_id)}-form"

          def self.scope(edit_id) = "post-edit-#{edit_id}"

          def view_template
            return if @edits.empty?

            Card(label: t(".label")) do
              ol(class: "edit-note-list") { @edits.each { item(it) } }
            end
          end

          private

          def edit_form(edit)
            details(class: "edit-note-edit", open: mine?(edit.id)) do
              summary(class: "btn sm") { t(".edit") }
              div(class: "form-stack") { fields(edit) }
            end
          end

          def editor_props(edit, form)
            { name: "edit[#{FIELD}]", value: mine?(edit.id) ? @noting[:note] : edit.note, height: HEIGHT,
              renderer: "posts", label: t(".edit_label"), form: }
          end

          def errors_for(id) = mine?(id) ? @noting[:errors] : Blog::Constants::EMPTY_HASH

          def fields(edit)
            form = self.class.form_id(edit.id)
            scope = self.class.scope(edit.id)
            errors = errors_for(edit.id)

            MarkdownEditor(**FieldError.control_attributes(FIELD, errors, scope), **editor_props(edit, form))
            FieldError(field: FIELD, errors:, scope:)
            Button(variant: :pri, type: "submit", small: true, form:) { t(".save") }
          end

          def item(edit)
            li(class: "edit-note", id: self.class.scope(edit.id)) do
              Moment(at: edit.created_at, class: "edit-note-time")
              div(class: "post-body edit-note-body") { raw(safe(::Posts::Markdown.to_html(edit.note).strip)) }
              edit_form(edit)
            end
          end

          def mine?(id) = @noting.key?(:id) && @noting[:id] == id
        end
      end
    end
  end
end
