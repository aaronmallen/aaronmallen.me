# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Show < View
          include Components::Tasks

          CREDIT_SEPARATOR = ", "
          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          LISTS = %w[today next someday external].to_h { [Blog::Types::TaskFilter[it], ".lists.#{it}"] }.freeze
          PREFIX = "#"
          STATUSES = {
            Blog::Types::TaskStatus["open"] => [nil, "fa-regular fa-circle", ".statuses.open"],
            Blog::Types::TaskStatus["in_progress"] => [:blue, "fa-solid fa-circle-play", ".statuses.in_progress"],
            Blog::Types::TaskStatus["done"] => [:green, "fa-solid fa-circle-check", ".statuses.done"],
            Blog::Types::TaskStatus["canceled"] => [:sand, "fa-solid fa-ban", ".statuses.canceled"],
          }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :note_html, Blog::Types::String.optional
          prop :linking, Blog::Types::Hash
          prop :records, Blog::Types::Hash
          prop :timeline, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :forms, Blog::Types::Hash
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            article(class: "read-page", data: { task_read: @task.id }) do
              head
              meta
              status_bar
              note
              facts
              links
              linked
              Timeline(task: @task, entries: @timeline, forms: @forms, tab: @filter, origin: @origin)
            end
          end

          private

          def back
            BackLink(href: back_path, data: { task_close: true }) { t(today? ? ".back_today" : ".back_tasks") }
          end

          def back_path = today? ? path(:admin_root) : path(:admin_tasks, filter: @filter)

          def credit(credit) = credit[:agent] ? t(".agent", **credit.slice(:agent, :model)) : t(".owner")

          def credits = @task.credits.map { credit(it) }.join(CREDIT_SEPARATOR)

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: @filter, origin: @origin)

            Button(href:, data: { task_open_edit: true }, icon: "fa-regular fa-pen-to-square") { t(".edit") }
          end

          def fact(label_key, value)
            div(class: "task-fact") do
              dt { t(label_key) }
              dd { value.is_a?(Time) ? Moment(at: value) : plain(value) }
            end
          end

          def fact_values
            {
              ".created" => @task.created_at,
              ".updated" => @task.updated_at,
              ".completed" => @task.completed_at,
              ".sprint" => sprint_day,
              ".carried" => t(".carried_count", count: @task.carried_count),
              ".worked" => Blog::Helpers::Figures.hours(@task.worked_seconds),
              ".contributors" => credits,
            }.compact
          end

          def facts
            dl(class: "task-facts") { fact_values.each { |key, value| fact(key, value) } }
            TotalForm(task: @task, totaling: @forms[:totaling], tab: @filter, origin: @origin)
          end

          def head
            PageHead(title: @task.title, kicker:) do
              back
              edit
            end
          end

          def key = PREFIX + @task.id.to_s

          def kicker = dotted(key, reference)

          def linked
            RecordLinks::Section(
              records: @records, kind: "task", id: @task.id, fields: { filter: @filter, origin: @origin },
              find_path: path(:admin_task, id: @task.id),
            )
          end

          def links
            Card(label: t(".related"), title: t(".links")) do
              LinkEditor(task: @task, tab: @filter, origin: @origin, linking: @linking)
            end
          end

          def meta
            p(class: "read-meta") do
              RecordKey(kind: "task", id: @task.id)
              status
              span(class: "read-meta-list") { t(LISTS.fetch(@task.place)) }
              SourceLink(source: @task.source)
              @task.tags.each { Tag(tag: it) }
            end
          end

          def note
            return unless @note_html

            Card(label: t(".note_label"), title: t(".note")) do
              div(class: "markdown-body post-body") { raw(safe(@note_html)) }
            end
          end

          def reference = @task.source && ::Tasks::Structs::SourceReference.for(@task.source).key

          def sprint_day = @task.sprint ? l(@task.sprint.sprint_date, format: :medium) : t(".unscheduled")

          def status
            color, icon, label_key = STATUSES.fetch(@task.status)

            Pill(color:, icon:) { t(label_key) }
          end

          def status_bar
            div(class: "task-stbar") do
              Controls(task: @task, filter: @filter, origin: @origin, moves: false)
              p(class: "task-stbar-worked") do
                Icon("fa-regular fa-clock")
                plain t(".worked_total", span: Blog::Helpers::Figures.hours(@task.tracked_seconds))
                span(class: "task-stbar-running") { t(".running") } if @task.running_session
              end
            end
          end

          def today? = @origin == FROM_TODAY
        end
      end
    end
  end
end
