# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Dialog < Component
          ID = "person-dialog"
          TITLE_ID = "person-dialog-title"
          ATTRIBUTES = {
            id: ID, class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID },
            data: { dialog: "static", person_dialog: true },
          }.freeze

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                head
                div(data: { person_dialog_body: true })
              end
            end
          end

          private

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
