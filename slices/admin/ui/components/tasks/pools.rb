# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Pools < Component
          EMPTY = {
            Blog::Types::TaskList["next"] => ".empty.next",
            Blog::Types::TaskList["someday"] => ".empty.someday",
            Blog::Types::TaskList["external"] => ".empty.external",
          }.freeze
          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          LISTS = {
            Blog::Types::TaskList["next"] => ".lists.next",
            Blog::Types::TaskList["someday"] => ".lists.someday",
            Blog::Types::TaskList["external"] => ".lists.external",
          }.freeze
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
              header(class: "card-head") do
                div { span(class: "card-label") { t(".pull_from") } }
                div(class: "card-side") { switch }
              end
              LISTS.each_key { pool(it) }
            end
          end

          private

          def from_today? = @origin == FROM_TODAY

          def meta(task, list)
            p(class: "task-meta") do
              SourceLink(source: task.source)
              task.tags.each { Tag(tag: it, href: tag_path(it, list)) }
            end
          end

          def pool(list)
            div(data: { pool_panel: list }, hidden: list != @pool) { rows(list) }
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
            Form(action: path(:admin_move_task, id: task.id, filter: TODAY)) do
              input(type: "hidden", name: "origin", value: @origin)
              input(type: "hidden", name: "pool", value: list)
              Button(variant: :pri, type: "submit", small: true, aria: { label: t(".pull_task", task: task.title) }) do
                IconLabel(icon: "fa-solid fa-arrow-turn-up") { t(".pull") }
              end
            end
          end

          def row(task, list)
            div(class: "li", data: { key_row: true }) do
              div(class: "li-main") do
                span(class: "li-title") { task.title }
                meta(task, list)
              end
              div(class: "li-side") { pull_form(task, list) }
            end
          end

          def rows(list)
            waiting = @pools.fetch(list)
            return Empty { t(EMPTY.fetch(list)) } if waiting.empty?

            div(class: "task-planner-list") { waiting.each { row(it, list) } }
          end

          def switch = SegmentedLinks(label: t(".pull_from"), items: LISTS.keys.map { pool_link(it) })

          def tag_path(tag, list) = path(:admin_tasks, filter: list, q: "tag:#{tag.name}")
        end
      end
    end
  end
end
