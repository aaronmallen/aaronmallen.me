# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SyncButton < Component
          def view_template
            Form(action: path(:admin_sync_issues)) do
              Button(type: "submit", small: true) do
                i(class: "fa-solid fa-rotate", aria: { hidden: "true" })
                span { t(".label") }
              end
            end
          end
        end
      end
    end
  end
end
