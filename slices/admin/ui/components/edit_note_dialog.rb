# frozen_string_literal: true

module Admin
  module UI
    module Components
      class EditNoteDialog < Component
        prop :title_id, Blog::Types::String, default: -> { "edit-note-dialog-title" }

        def view_template
          Dialog(title_id: @title_id, data: { edit_note_dialog: true }) do |dialog|
            dialog.foot do
              Button(variant: :gh, small: true, data: { edit_note_decline: true }) { t(".cancel") }
              Button(variant: :pri, small: true, data: { edit_note_accept: true }) { t(".save") }
            end

            h2(id: @title_id, class: "card-title") { t(".title") }
            div(data: { edit_note_slot: true })
          end
        end
      end
    end
  end
end
