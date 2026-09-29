# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateDialog < Component
          ID = "task-create"
          SCOPE = "create"
          TITLE_ID = "task-create-title"
          ATTRIBUTES = {
            id: ID, class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID }, data: { dialog: true },
          }.freeze

          prop :today, Blog::Types::Date

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                h2(id: TITLE_ID, class: "card-title", data: { task_modal_title: t(".edit_title") }) { t(".title") }
                div(data: { task_modal_body: true }) do
                  TaskForm(scope: SCOPE, today: @today) { close }
                end
              end
            end
          end

          private

          def close
            Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
          end
        end
      end
    end
  end
end
