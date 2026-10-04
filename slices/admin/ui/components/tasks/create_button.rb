# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateButton < Component
          prop :origin, Blog::Types::TaskOrigin.optional, default: nil

          def view_template
            CreateLink(href:, label: t(".label"), dialog: CreateDialog::ID)
          end

          private

          def href = @origin ? path(:admin_new_task, origin: @origin) : path(:admin_new_task)
        end
      end
    end
  end
end
