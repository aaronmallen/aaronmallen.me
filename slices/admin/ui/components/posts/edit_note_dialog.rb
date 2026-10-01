# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditNoteDialog < Component
          TITLE_ID = "edit-note-dialog-title"
          ATTRIBUTES = {
            class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID }, data: { edit_note_dialog: true },
          }.freeze

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                h2(id: TITLE_ID, class: "card-title") { t(".title") }
                div(data: { edit_note_slot: true })
                foot
              end
            end
          end

          private

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
end
