# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Show < View
          include Components::Tasks

          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          PREFIX = "#"
          STATUSES = {
            Blog::Types::TaskStatus["open"] => [nil, "fa-regular fa-circle", ".statuses.open"],
            Blog::Types::TaskStatus["in_progress"] => [:blue, "fa-solid fa-circle-play", ".statuses.in_progress"],
            Blog::Types::TaskStatus["done"] => [:green, "fa-solid fa-circle-check", ".statuses.done"],
            Blog::Types::TaskStatus["canceled"] => [:sand, "fa-solid fa-ban", ".statuses.canceled"],
          }.freeze

          def initialize(task:, note_html:, linking:, filter:, origin:)
            super()
            @task = task
            @note_html = note_html
            @linking = linking
            @filter = filter
            @origin = origin
          end

          def view_template
            article(class: "task-read", data: { task_read: @task.id }) do
              PageHead(title: @task.title, sub: t(".sub", key:)) { back }
              meta
              div(class: "task-read-acts") { Controls(task: @task, filter: @filter, origin: @origin, moves: false) }
              note
              facts
              Card(label: t(".related"), title: t(".links")) do
                LinkEditor(task: @task, tab: @filter, origin: @origin, linking: @linking, page: true)
              end
            end
          end

          private

          def back
            a(class: "btn", href: back_path) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(today? ? ".back_today" : ".back_tasks") }
            end
          end

          def back_path = today? ? path(:admin_root) : path(:admin_tasks, filter: @filter)

          def fact(label_key, value)
            div(class: "task-fact") do
              dt { t(label_key) }
              dd { value }
            end
          end

          def facts
            dl(class: "task-facts") do
              fact(".created", stamp(@task.created_at))
              fact(".updated", stamp(@task.updated_at))
              fact(".completed", stamp(@task.completed_at)) if @task.completed_at
              fact(".sprint", sprint_day)
              fact(".carried", t(".carried_count", count: @task.carried_count))
            end
          end

          def key = PREFIX + @task.id.to_s

          def meta
            p(class: "task-meta task-read-meta") do
              TaskKey(task: @task)
              status
              SourceLink(source: @task.source)
              @task.tags.each { tag(it) }
            end
          end

          def note
            return unless @note_html

            Card(label: t(".note_label"), title: t(".note")) do
              div(class: "task-body post-body") { raw(safe(@note_html)) }
            end
          end

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

          def tag(tag)
            span(class: ["task-tag", Blog::UI::Components::Pill.for_tag_color(tag.color)&.to_s]) { "##{tag.name}" }
          end

          def today? = @origin == FROM_TODAY
        end
      end
    end
  end
end
