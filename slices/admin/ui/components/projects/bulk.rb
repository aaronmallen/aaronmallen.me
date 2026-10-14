# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Bulk < Component
          ICON = "fa-solid fa-arrow-right"
          ID = "board-bulk"
          MOVE = "move"

          prop :project_id, Blog::Types::Integer

          def view_template
            BulkBar(id: ID, action: path(:admin_bulk_project_tasks, id: @project_id), label: t(".label"),
                    toggled: true) do |bar|
              bar.choose("to", MOVE, prompt: t(".pick_column"), options: columns, icon: ICON, label: t(".move"))
            end
          end

          private

          def columns = BoardCard::NAMES.transform_values { t(it) }
        end
      end
    end
  end
end
