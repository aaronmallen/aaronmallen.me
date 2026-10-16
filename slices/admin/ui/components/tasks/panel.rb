# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Panel < Component
          ID = "task-panel"
          BODY = { tabindex: "-1", data: { task_panel_body: true } }.freeze

          def view_template
            Dialog(
              id: ID, class: "wide task-panel", body: BODY, aria: { label: t(".label") }, data: { task_panel: true },
            )
          end
        end
      end
    end
  end
end
