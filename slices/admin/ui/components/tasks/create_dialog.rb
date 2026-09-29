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
            id: ID, class: "task-dialog", hidden: true, aria: { labelledby: TITLE_ID }, data: { dialog: "static" },
          }.freeze

          prop :today, Blog::Types::Date
          prop :origin, Blog::Types::TaskOrigin.optional, default: nil

          def view_template
            dialog(**ATTRIBUTES) do
              div(class: "task-dialog-box") do
                head
                div(data: { task_modal_body: true }) do
                  TaskForm(scope: SCOPE, today: @today, returns:) { close }
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
              h2(id: TITLE_ID, class: "card-title", data: { task_modal_title: t(".edit_title") }) { t(".title") }
              dismiss
            end
          end

          def returns = @origin ? { origin: @origin } : Dry::Core::Constants::EMPTY_HASH
        end
      end
    end
  end
end
