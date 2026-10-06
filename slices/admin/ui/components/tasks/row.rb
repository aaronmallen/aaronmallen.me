# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Row < Component
          EDIT = "e"
          ORIGIN = Blog::Types::TaskOrigin["tasks"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :lead, Blog::Types::Integer.optional, default: nil
          prop :ordered, Blog::Types::Bool, default: true
          prop :origin, Blog::Types::String, default: ORIGIN
          prop :scheduled, Blog::Types::Date.optional, default: nil
          prop :tab, Blog::Types::String.optional, default: nil
          prop :bulk, Blog::Types::String.optional, default: nil

          def view_template
            div(class: classes, data: { key_row: true, **order }) do
              RecordKey(kind: "task", id: @task.id)
              pick if @bulk
              task_title
              meta
              side
              Links(links: @task.links) unless @task.links.empty?
            end
          end

          private

          def blocked
            Pill(color: :pink, icon: "fa-solid fa-lock") { t(".blocked") }
          end

          def blocked? = !@task.closed? && @task.blocked?

          def carried
            Pill(color: :sand, icon: "fa-solid fa-rotate-left") { t(".carried", count: @task.carried_count) }
          end

          def carried? = !@task.closed? && @task.carried_count.positive?

          def classes
            ["task", ("done" if @task.closed?), ("canceled" if @task.canceled?), ("doing" if @task.in_progress?)]
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: tab, origin: @origin)
            label = t(".edit")

            aria = { label:, keyshortcuts: EDIT }
            data = { task_open_edit: true, key: EDIT, key_label: t(".edit_key") }

            Button(href:, title: label, aria:, data:, small: true, icon: "fa-regular fa-pen-to-square")
          end

          def in_progress
            Pill(color: :blue, icon: "fa-solid fa-circle-play") { t(".in_progress") }
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

          def order
            return Blog::Constants::EMPTY_HASH unless ordered?

            { task_id: @task.id, task_order: @task.list || @task.sprint_id }
          end

          def ordered? = @ordered && !@task.closed?

          def pick
            BulkCheck(form: @bulk, value: @task.id, label: t(".pick", task: @task.title), class: "task-pick")
          end

          def scheduled_pill
            date = l(@scheduled, format: :short)

            Pill(color: :orange, icon: "fa-regular fa-calendar") { t(".scheduled", date:) }
          end

          def side
            div(class: "task-acts") do
              Grip(task: @task, lead: @lead) if ordered?
              Controls(task: @task, filter: @filter, origin: @origin, keys: true)
              edit
            end
          end

          def tab = @tab || @filter

          def tag_path(tag) = path(:admin_tasks, filter: tab, q: "tag:#{tag.name}")

          def tags = @task.tags.each { Tag(tag: it, href: tag_path(it)) }

          def task_title
            href = path(:admin_task, id: @task.id, filter: tab, origin: @origin)

            a(class: "task-title", href:, data: { task_open: true, key_open: true }) do
              @task.title
            end
          end

          def waiting? = !@scheduled.nil? && @scheduled > @today && !@task.closed?
        end
      end
    end
  end
end
