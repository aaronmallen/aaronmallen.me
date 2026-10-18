# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class PersonDialog < Component
          ID = "person-dialog"

          def view_template
            data = { person_dialog: true, person_dialog_failed: t(".failed") }

            Dialog(id: ID, title: t(".title"), static: true, data:) do
              div(data: { person_dialog_body: true })
            end
          end
        end
      end
    end
  end
end
