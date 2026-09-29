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

          prop :origin, Blog::Types::String
          prop :pool, Blog::Types::String
          prop(
            :pools,
            Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))),
          )

          def view_template
            div(class: "task-planner-pull") do
              header(class: "card-head") do
                div { span(class: "card-label") { t(".pull_from") } }
                div(class: "card-side") { switch }
              end
              rows
            end
          end

          private

          def from_today? = @origin == FROM_TODAY

          def meta(task)
            p(class: "task-meta") do
              SourceLink(source: task.source)
              task.tags.each { tag(it) }
            end
          end

          def pool_link(list)
            current = list == @pool

            a(class: ["seg-option", ("current" if current)], href: pool_path(list),
              aria: { current: ("true" if current) }) do
              t(LISTS.fetch(list), count: @pools.fetch(list).size)
            end
          end

          def pool_path(list)
            query = from_today? ? { pool: list } : { filter: TODAY, pool: list }

            path(from_today? ? :admin_root : :admin_tasks, **query)
          end

          def pull_form(task)
            Form(action: path(:admin_move_task, id: task.id, filter: TODAY)) do
              input(type: "hidden", name: "origin", value: @origin)
              Button(variant: :pri, type: "submit", small: true, aria: { label: t(".pull_task", task: task.title) }) do
                i(class: "fa-solid fa-arrow-turn-up", aria: { hidden: "true" })
                span { t(".pull") }
              end
            end
          end

          def row(task)
            div(class: "li") do
              div(class: "li-main") do
                span(class: "li-title") { task.title }
                meta(task)
              end
              div(class: "li-side") { pull_form(task) }
            end
          end

          def rows
            waiting = @pools.fetch(@pool)
            return Empty { t(EMPTY.fetch(@pool)) } if waiting.empty?

            div(class: "task-planner-list") { waiting.each { row(it) } }
          end

          def switch
            div(class: "seg", role: "group", aria: { label: t(".pull_from") }) do
              LISTS.each_key { pool_link(it) }
            end
          end

          def tag(tag)
            span(class: ["task-tag", Blog::UI::Components::Pill.for_tag_color(tag.color)&.to_s]) { "##{tag.name}" }
          end
        end
      end
    end
  end
end
