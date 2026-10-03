# frozen_string_literal: true

module Admin
  module UI
    module Components
      class EditNoteDialog < Component
        prop :title_id, Blog::Types::String, default: -> { "edit-note-dialog-title" }

        def view_template
          dialog(**attributes) do
            div(class: "task-dialog-box") do
              h2(id: @title_id, class: "card-title") { t(".title") }
              div(data: { edit_note_slot: true })
              foot
            end
          end
        end

        private

        def attributes
          { class: "task-dialog", hidden: true, aria: { labelledby: @title_id }, data: { edit_note_dialog: true } }
        end

        def foot
          div(class: "confirm-dialog-foot") do
            Button(variant: :gh, small: true, data: { edit_note_decline: true }) { t(".cancel") }
            Button(variant: :pri, small: true, data: { edit_note_accept: true }) { t(".save") }
          end
        end
      end
    end
  end
end
