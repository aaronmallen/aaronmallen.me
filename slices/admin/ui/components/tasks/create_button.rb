# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateButton < Component
          def view_template
            a(class: "btn pri", href: path(:admin_new_task), data: { dialog_open: CreateDialog::ID }) do
              i(class: "fa-solid fa-plus", aria: { hidden: "true" })
              span { t(".label") }
            end
          end
        end
      end
    end
  end
end
