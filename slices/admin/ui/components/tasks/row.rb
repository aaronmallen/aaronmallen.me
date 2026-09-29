# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Row < Component
          ORIGIN = Blog::Types::TaskOrigin["tasks"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :first, Blog::Types::Bool, default: false
          prop :last, Blog::Types::Bool, default: false
          prop :ordered, Blog::Types::Bool, default: true
          prop :origin, Blog::Types::String, default: ORIGIN
          prop :page, Blog::Types::Integer, default: 1
          prop :scheduled, Blog::Types::Date.optional, default: nil
          prop :tab, Blog::Types::String.optional, default: nil

          def view_template
            div(class: classes) do
              TaskKey(task: @task)
              task_title
              meta
              side
              Links(links: @task.links) unless @task.links.empty?
            end
          end

          private

          def blocked
            Pill(color: :pink) do
              i(class: "fa-solid fa-lock", aria: { hidden: "true" })
              span { t(".blocked") }
            end
          end

          def blocked? = !@task.closed? && @task.blocked?

          def carried
            Pill(color: :sand) do
              i(class: "fa-solid fa-rotate-left", aria: { hidden: "true" })
              span { t(".carried", count: @task.carried_count) }
            end
          end

          def carried? = !@task.closed? && @task.carried_count.positive?

          def classes
            ["task", ("done" if @task.closed?), ("canceled" if @task.canceled?), ("doing" if @task.in_progress?)]
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: tab, origin: @origin)
            label = t(".edit")

            a(class: "btn sm", href:, title: label, aria: { label: }, data: { task_open_edit: true }) do
              i(class: "fa-regular fa-pen-to-square", aria: { hidden: "true" })
            end
          end

          def in_progress
            Pill(color: :blue) do
              i(class: "fa-solid fa-circle-play", aria: { hidden: "true" })
              span { t(".in_progress") }
            end
          end

          def meta
            p(class: "task-meta") do
              blocked if blocked?
              in_progress if @task.in_progress?
              scheduled_pill if waiting?
              carried if carried?
              SourceLink(source: @task.source)
              tags
              Closed(task: @task) if @task.closed?
            end
          end

          def scheduled_pill
            Pill(color: :orange) do
              i(class: "fa-regular fa-calendar", aria: { hidden: "true" })
              span { t(".scheduled", date: l(@scheduled, format: :short)) }
            end
          end

          def side
            div(class: "task-acts") do
              Order(task: @task, filter: @filter, first: @first, last: @last, origin: @origin, page: @page) if @ordered
              Controls(task: @task, filter: @filter, origin: @origin)
              edit
            end
          end

          def tab = @tab || @filter

          def tag_path(tag) = path(:admin_tasks, filter: tab, q: "tag:#{tag.name}")

          def tags = @task.tags.each { Tag(tag: it, href: tag_path(it)) }

          def task_title
            href = path(:admin_task, id: @task.id, filter: tab, origin: @origin)

            a(class: "task-title", href:, data: { task_open: true }) do
              @task.title
            end
          end

          def waiting? = !@scheduled.nil? && @scheduled > @today && !@task.closed?
        end
      end
    end
  end
end
