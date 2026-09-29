# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ConfirmDialog < Component
        ID = "confirm-dialog"
        MESSAGE_ID = "confirm-dialog-message"
        ATTRIBUTES = {
          id: ID, class: "task-dialog", role: "alertdialog", hidden: true, aria: { labelledby: MESSAGE_ID },
          data: { confirm_dialog: true },
        }.freeze

        def view_template
          dialog(**ATTRIBUTES) do
            div(class: "task-dialog-box") do
              p(id: MESSAGE_ID, class: "confirm-dialog-message", data: { confirm_message: true })
              div(class: "confirm-dialog-foot") do
                Button(variant: :gh, small: true, autofocus: true, data: { confirm_decline: true }) { t(".decline") }
                Button(variant: :warn, small: true, data: { confirm_accept: true }) { t(".accept") }
              end
            end
          end
        end
      end
    end
  end
end
