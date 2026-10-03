# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Show < View
          include Components::Tasks

          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          KICKER_SEPARATOR = " · "
          PREFIX = "#"
          STATUSES = {
            Blog::Types::TaskStatus["open"] => [nil, "fa-regular fa-circle", ".statuses.open"],
            Blog::Types::TaskStatus["in_progress"] => [:blue, "fa-solid fa-circle-play", ".statuses.in_progress"],
            Blog::Types::TaskStatus["done"] => [:green, "fa-solid fa-circle-check", ".statuses.done"],
            Blog::Types::TaskStatus["canceled"] => [:sand, "fa-solid fa-ban", ".statuses.canceled"],
          }.freeze

          def initialize(task:, note_html:, linking:, timeline:, commenting:, filter:, origin:)
            super()
            @task = task
            @note_html = note_html
            @linking = linking
            @timeline = timeline
            @commenting = commenting
            @filter = filter
            @origin = origin
          end

          def view_template
            article(class: "task-read", data: { task_read: @task.id }) do
              head
              meta
              div(class: "task-read-acts") { Controls(task: @task, filter: @filter, origin: @origin, moves: false) }
              note
              facts
              links
              Timeline(task: @task, entries: @timeline, commenting: @commenting, tab: @filter, origin: @origin)
            end
          end

          private

          def back
            a(class: "btn", href: back_path, data: { task_close: true }) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(today? ? ".back_today" : ".back_tasks") }
            end
          end

          def back_path = today? ? path(:admin_root) : path(:admin_tasks, filter: @filter)

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: @filter, origin: @origin)

            a(class: "btn", href:, data: { task_open_edit: true }) do
              i(class: "fa-regular fa-pen-to-square", aria: { hidden: "true" })
              span { t(".edit") }
            end
          end

          def fact(label_key, value)
            div(class: "task-fact") do
              dt { t(label_key) }
              dd { value }
            end
          end

          def fact_values
            {
              ".created" => stamp(@task.created_at),
              ".updated" => stamp(@task.updated_at),
              ".completed" => @task.completed_at && stamp(@task.completed_at),
              ".sprint" => sprint_day,
              ".carried" => t(".carried_count", count: @task.carried_count),
              ".worked" => Blog::Figures.hours(@task.worked_seconds),
            }.compact
          end

          def facts
            dl(class: "task-facts") { fact_values.each { |key, value| fact(key, value) } }
          end

          def head
            PageHead(title: @task.title, kicker:) do
              back
              edit
            end
          end

          def key = PREFIX + @task.id.to_s

          def kicker = [key, reference].compact.join(KICKER_SEPARATOR)

          def links
            Card(label: t(".related"), title: t(".links")) do
              LinkEditor(task: @task, tab: @filter, origin: @origin, linking: @linking)
            end
          end

          def meta
            p(class: "task-meta task-read-meta") do
              TaskKey(task: @task)
              status
              SourceLink(source: @task.source)
              @task.tags.each { Tag(tag: it, href: tag_path(it)) }
            end
          end

          def note
            return unless @note_html

            Card(label: t(".note_label"), title: t(".note")) do
              div(class: "task-body post-body") { raw(safe(@note_html)) }
            end
          end

          def reference = @task.source && Structs::TaskSourceReference.for(@task.source).key

          def sprint_day
            sprint = @task.sprint

            sprint ? l(sprint.sprint_date, format: :medium) : t(".unscheduled")
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)

          def status
            color, icon, label_key = STATUSES.fetch(@task.status)

            Pill(color:) do
              i(class: icon, aria: { hidden: "true" })
              span { t(label_key) }
            end
          end

          def tag_path(tag) = path(:admin_tasks, filter: @filter, q: "tag:#{tag.name}")

          def today? = @origin == FROM_TODAY
        end
      end
    end
  end
end
