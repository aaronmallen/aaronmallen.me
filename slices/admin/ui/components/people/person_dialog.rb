# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class PersonDialog < Component
          ID = "person-dialog"
          TITLE_ID = "person-dialog-title"

          def view_template
            Dialog(id: ID, title_id: TITLE_ID, title: t(".title"), data: { dialog: "static", person_dialog: true }) do
              div(data: { person_dialog_body: true })
            end
          end
        end
      end
    end
  end
end
