# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Panel < Component
          ID = "task-panel"
          ATTRIBUTES = { id: ID, class: "dialog wide", hidden: true, data: { dialog: true, task_panel: true } }.freeze

          def view_template
            dialog(**ATTRIBUTES, aria: { label: t(".label") }) do
              div(class: "dialog-box") do
                div(class: "dialog-body", tabindex: "-1", data: { task_panel_body: true })
              end
            end
          end
        end
      end
    end
  end
end
