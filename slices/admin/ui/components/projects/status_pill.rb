# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class StatusPill < Component
          STATUSES = {
            Blog::Types::ProjectStatus["active"] => [:green, "fa-solid fa-circle-check", ".active"],
            Blog::Types::ProjectStatus["wip"] => [:orange, "fa-solid fa-hammer", ".wip"],
            Blog::Types::ProjectStatus["paused"] => [:sand, "fa-regular fa-circle-pause", ".paused"],
            Blog::Types::ProjectStatus["archived"] => [nil, "fa-solid fa-box-archive", ".archived"],
          }.freeze

          prop :status, Blog::Types::ProjectStatus

          def view_template
            color, icon, label_key = STATUSES.fetch(@status)

            Pill(color:, icon:) { t(label_key) }
          end
        end
      end
    end
  end
end
