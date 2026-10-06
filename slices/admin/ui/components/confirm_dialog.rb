# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ConfirmDialog < Component
        DATA = { dialog: true, confirm_dialog: true }.freeze
        ID = "confirm-dialog"
        MESSAGE_ID = "confirm-dialog-message"

        def view_template
          Dialog(id: ID, title_id: MESSAGE_ID, role: "alertdialog", data: DATA) do |dialog|
            dialog.foot do
              Button(variant: :gh, small: true, autofocus: true, data: { dialog_close: true }) { t(".decline") }
              Button(variant: :warn, small: true, data: { dialog_accept: true }) { t(".accept") }
            end

            p(id: MESSAGE_ID, class: "confirm-dialog-message", data: { confirm_message: true })
          end
        end
      end
    end
  end
end
