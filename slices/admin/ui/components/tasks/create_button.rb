# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateButton < Component
          prop :origin, Blog::Types::TaskOrigin.optional, default: nil

          def view_template
            a(class: "btn pri", href:, data: { dialog_open: CreateDialog::ID }) do
              i(class: "fa-solid fa-plus", aria: { hidden: "true" })
              span { t(".label") }
            end
          end

          private

          def href = @origin ? path(:admin_new_task, origin: @origin) : path(:admin_new_task)
        end
      end
    end
  end
end
