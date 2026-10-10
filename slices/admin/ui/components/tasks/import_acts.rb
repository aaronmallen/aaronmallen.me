# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class ImportActs < Component
          def view_template
            Button(href: path(:admin_task_rules), small: true, icon: "fa-solid fa-tag") { t(".rules") }
            Form(action: path(:admin_sync_issues)) do
              Button(type: "submit", small: true, icon: "fa-solid fa-rotate") { t(".sync") }
            end
          end
        end
      end
    end
  end
end
