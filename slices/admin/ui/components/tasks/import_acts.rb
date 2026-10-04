# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class ImportActs < Component
          def view_template
            a(class: "btn sm", href: path(:admin_task_tag_rules)) do
              i(class: "fa-solid fa-tag", aria: { hidden: "true" })
              span { t(".rules") }
            end
            SyncButton()
          end
        end
      end
    end
  end
end
