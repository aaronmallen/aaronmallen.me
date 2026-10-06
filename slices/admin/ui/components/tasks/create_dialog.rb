# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateDialog < Component
          ID = "task-create"
          SCOPE = "create"
          TITLE_ID = "task-create-title"

          prop :today, Blog::Types::Date
          prop :origin, Blog::Types::TaskOrigin.optional, default: nil

          def view_template
            Dialog(
              id: ID, title_id: TITLE_ID, title: t(".title"), title_data: { task_modal_title: t(".edit_title") },
              data: { dialog: "static" },
            ) do
              div(data: { task_modal_body: true }) do
                TaskForm(scope: SCOPE, today: @today, returns:) { close }
              end
            end
          end

          private

          def close
            Button(variant: :gh, small: true, data: { dialog_close: true }) { t(".cancel") }
          end

          def returns = @origin ? { origin: @origin } : Blog::Constants::EMPTY_HASH
        end
      end
    end
  end
end
