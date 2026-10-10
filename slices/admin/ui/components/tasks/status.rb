# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Status < Component
          STATUSES = {
            Blog::Types::TaskStatus["open"] => [nil, "fa-regular fa-circle"],
            Blog::Types::TaskStatus["in_progress"] => [:blue, "fa-solid fa-circle-play"],
            Blog::Types::TaskStatus["done"] => [:green, "fa-solid fa-circle-check"],
            Blog::Types::TaskStatus["canceled"] => [:sand, "fa-solid fa-ban"],
          }.freeze

          prop :status, Blog::Types::TaskStatus

          def view_template
            color, icon = STATUSES.fetch(@status)

            Pill(color:, icon:) { t(Helpers::TaskStatuses.name(@status)) }
          end
        end
      end
    end
  end
end
