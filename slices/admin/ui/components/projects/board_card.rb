# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class BoardCard < Component
          COLUMNS = Blog::Types::TaskColumn.values
          NAMES = COLUMNS.to_h { [it, "ui.views.projects.show.columns.#{it}"] }.freeze
          LEFT = "fa-solid fa-arrow-left"
          RIGHT = "fa-solid fa-arrow-right"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :project_id, Blog::Types::Integer

          def view_template
            div(class: classes, data: { key_row: true, menu: menu_path }) do
              head
              a(class: "kc-title", href: path(:admin_task, id: @task.id), data: { task_open: true, key_open: true }) do
                @task.title
              end
              Tasks::Meta(task: @task)
            end
          end

          private

          def arrow(step, icon)
            at = COLUMNS.index(@task.board_column) + step
            return unless at.between?(0, COLUMNS.size - 1)

            to = COLUMNS[at]
            label = t(".move", column: t(NAMES.fetch(to)))

            Form(action: path(:admin_move_project_task, id: @project_id, task_id: @task.id), data: { morph: true }) do
              input(type: "hidden", name: "to", value: to)
              Button(type: "submit", variant: :gh, small: true, icon:, label:)
            end
          end

          def classes = ["kc", ("doing" if @task.in_progress?), ("done" if @task.closed?)]

          def head
            div(class: "kc-h") do
              RecordKey(kind: "task", id: @task.id)
              div(class: "hov") do
                arrow(-1, LEFT)
                arrow(1, RIGHT)
              end
            end
          end

          def menu_path = path(:admin_task_menu, id: @task.id, project: @project_id)
        end
      end
    end
  end
end
