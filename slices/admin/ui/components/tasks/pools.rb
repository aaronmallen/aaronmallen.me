# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Pools < Component
          EMPTY = Blog::Types::TaskList.values.to_h { [it, ".empty.#{it}"] }.freeze
          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          LISTS = Blog::Types::TaskList.values.to_h { [it, ".lists.#{it}"] }.freeze
          TODAY = Blog::Types::TaskFilter["today"]

          prop :counts, Blog::Types::Hash
          prop :origin, Blog::Types::String
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )

          def view_template
            div(class: "task-planner-pull", data: { pools: "" }) do
              switch
              div(data: { pool_panel: @pool }) { rows }
            end
          end

          private

          def from_today? = @origin == FROM_TODAY

          def menu_path(task) = path(:admin_task_menu, id: task.id, filter: TODAY, origin: @origin)

          def meta(task)
            p(class: "task-meta") do
              RecordKey(kind: "task", id: task.id)
              SourceLink(source: task.source)
              task.tags.each { Tag(tag: it) }
            end
          end

          def pool_link(list)
            {
              href: pool_path(list),
              text: t(LISTS.fetch(list), count: @counts.fetch(list)),
              current: list == @pool,
              data: { pool: list },
            }
          end

          def pool_path(list)
            query = from_today? ? { pool: list } : { filter: TODAY, pool: list }

            path(from_today? ? :admin_root : :admin_tasks, **query)
          end

          def pull_form(task, list)
            Form(action: path(:admin_move_task, id: task.id, filter: TODAY), data: { morph: true }) do
              input(type: "hidden", name: "origin", value: @origin)
              input(type: "hidden", name: "pool", value: list)
              Button(type: "submit", small: true, class: "go", aria: { label: t(".pull_task", task: task.title) }) do
                IconLabel(icon: "fa-solid fa-arrow-turn-up") { t(".pull") }
              end
            end
          end

          def row(task, list)
            ListItem(title: task.title, hover: true, data: { menu: menu_path(task) }) do |item|
              item.meta { meta(task) }
              pull_form(task, list)
            end
          end

          def rows
            waiting = @pools.fetch(@pool)
            return Empty { t(EMPTY.fetch(@pool)) } if waiting.empty?

            div(class: "task-planner-list") { waiting.each { row(it, @pool) } }
          end

          def switch = SegmentedLinks(label: t(".pull_from"), items: LISTS.keys.map { pool_link(it) })
        end
      end
    end
  end
end
