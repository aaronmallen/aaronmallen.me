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
              @task.tags.each { tag(it) }
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
              Order(task: @task, filter: @filter, first: @first, last: @last, origin: @origin) if @ordered
              Controls(task: @task, filter: @filter, origin: @origin)
            end
          end

          def tag(tag)
            span(class: ["task-tag", Blog::UI::Components::Pill.for_tag_color(tag.color)&.to_s]) { "##{tag.name}" }
          end

          def task_title
            a(class: "task-title", href: path(:admin_task, id: @task.id, filter: @tab || @filter, origin: @origin)) do
              @task.title
            end
          end

          def waiting? = !@scheduled.nil? && @scheduled > @today && !@task.closed?
        end
      end
    end
  end
end
