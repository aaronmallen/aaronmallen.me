# frozen_string_literal: true

module Admin
  module UI
    module Components
      class EditNoteDialog < Component
        prop :title_id, Blog::Types::String

        def view_template
          Dialog(
            title_id: @title_id, title: t(".title"), class: "modal", data: { dialog: true, edit_note_dialog: true },
          ) do |dialog|
            dialog.foot do
              Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
              Button(variant: :pri, small: true, data: { dialog_accept: true }) { t(".save") }
            end

            div(data: { edit_note_slot: true })
          end
        end
      end
    end
  end
end
