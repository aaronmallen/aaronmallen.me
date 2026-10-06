# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ConfirmDialog < Component
        ID = "confirm-dialog"
        MESSAGE_ID = "confirm-dialog-message"

        def view_template
          Dialog(id: ID, title_id: MESSAGE_ID, role: "alertdialog", data: { confirm_dialog: true }) do |dialog|
            dialog.foot do
              Button(variant: :gh, small: true, autofocus: true, data: { confirm_decline: true }) { t(".decline") }
              Button(variant: :warn, small: true, data: { confirm_accept: true }) { t(".accept") }
            end

            p(id: MESSAGE_ID, class: "confirm-dialog-message", data: { confirm_message: true })
          end
        end
      end
    end
  end
end
