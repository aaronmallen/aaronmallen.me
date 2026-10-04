# frozen_string_literal: true

module Admin
  module UI
    module Components
      module WorkEntries
        class LogDialog < Component
          ID = "work-log"
          SCOPE = "work-dialog"
          TITLE_ID = "work-log-title"
          ATTRIBUTES = {
            id: ID, class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID },
            data: { dialog: "static", work_dialog: true },
          }.freeze

          prop :return_to, Blog::Types::String.optional

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                head
                div(data: { work_dialog_body: true }) do
                  Fields(scope: SCOPE, returns: { return_to: @return_to }.compact) { close }
                end
              end
            end
          end

          private

          def close
            Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
          end

          def dismiss
            Button(variant: :gh, small: true, aria: { label: t(".close") }, data: { dialog_close: true }) do
              i(class: "fa-solid fa-xmark", aria: { hidden: "true" })
            end
          end

          def head
            div(class: "task-dialog-head") do
              h2(id: TITLE_ID, class: "card-title") { t(".title") }
              dismiss
            end
          end
        end
      end
    end
  end
end
