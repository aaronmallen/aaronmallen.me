# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class BoardList < Component
          CANCELED = Blog::Types::TaskColumn["canceled"]
          COLUMNS = Blog::Types::TaskColumn.values
          EMPTY = "ui.views.projects.show.empty"
          NAMES = BoardCard::NAMES

          prop :project, Blog::Types::Instance(ROM::Struct)
          prop :columns, Blog::Types::Hash
          prop :counts, Blog::Types::Hash.map(Blog::Types::TaskColumn, Blog::Types::Integer)
          prop :board, Blog::Types::Instance(Blog::BoardSizes)
          prop :return_to, Blog::Types::String

          def view_template
            div(class: "kb-list", data: { board_shows: "list" }) do
              div(class: "kls3", role: "group", aria: { label: t(".label", name: @project.name) }) do
                COLUMNS.each { group(it, @columns.fetch(it, Blog::Constants::EMPTY_ARRAY)) }
              end
              Hint { t(".hint") }
            end
          end

          private

          def body(name, tasks)
            return p(class: "kcol-empty") { t(EMPTY) } if tasks.empty?

            div(data: { key_list: true }) { tasks.each { row(it) } }
            LoadMore(
              project_id: @project.id, board: @board, column: name, count: @counts.fetch(name), shown: tasks.size,
            )
          end

          def column_names = @column_names ||= COLUMNS.to_h { [it, t(NAMES.fetch(it))] }

          def group(name, tasks)
            section(class: ["klg", "k-#{name}"], aria: { label: t(NAMES.fetch(name)) }, data: { board_column: name }) do
              details(open: name != CANCELED) do
                head(name)
                div(class: "klb") { body(name, tasks) }
              end
            end
          end

          def head(name)
            summary(class: "klh") do
              Icon("fa-solid fa-chevron-right")
              span(class: "kcol-dot", aria: { hidden: true })
              h2 { t(NAMES.fetch(name)) }
              span(class: "kcol-count") { @counts.fetch(name).to_s }
            end
          end

          def picker(task)
            AutoForm(
              method: Blog::UI::Components::Form::POST, class: "kls",
              action: path(:admin_move_project_task, id: @project.id, task_id: task.id),
              data: { morph: true, board_move: true },
            ) do
              HiddenFields(values: { return_to: @return_to })
              label do
                span(class: "sr-only") { t(".column_for", task: task.label) }
                Select(name: "to", options: column_names, selected: task.board_column)
              end
              noscript { Button(type: "submit", small: true) { t(".move") } }
            end
          end

          def row(task)
            div(class: "kli", data: { board_card: true }) do
              Tasks::Row(
                task:, filter: task.place, today: Blog::TimeZone.today, ordered: false, return_to: @return_to,
                project_id: @project.id,
              )
              picker(task)
            end
          end
        end
      end
    end
  end
end
