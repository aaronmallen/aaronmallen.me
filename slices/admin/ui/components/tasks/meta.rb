# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Meta < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :scheduled, Blog::Types::Date.optional, default: nil

          def view_template
            p(class: "task-meta") do
              in_progress if @task.in_progress?
              marks
              SourceLink(source: @task.source)
              @task.tags.each { Tag(tag: it) }
              worked if worked?
              comments
              Links(links: @task.links)
              Closed(task: @task) if @task.closed?
            end
          end

          private

          def carried = mark(:sand, "fa-solid fa-rotate-left") { t(".carried", count: @task.carried_count) }

          def comments
            count = @task.comment_count
            return unless count.positive?

            span(class: "task-mark", title: t(".comments", count:)) do
              Icon("fa-regular fa-comment")
              plain count.to_s
            end
          end

          def hours(seconds) = Blog::Helpers::Figures.hours(seconds)

          def in_progress
            tracked = @task.tracked_seconds

            mark(:blue, "fa-solid fa-circle-play") do
              tracked.positive? ? t(".in_progress_for", span: hours(tracked)) : t(".in_progress")
            end
          end

          def mark(tone, icon, &)
            span(class: ["task-mark", tone]) do
              Icon(icon)
              plain(yield)
            end
          end

          def marks
            return if @task.closed?

            mark(:pink, "fa-solid fa-lock") { t(".blocked") } if @task.blocked?
            carried if @task.carried_count.positive?
            return unless @scheduled

            mark(:orange, "fa-regular fa-calendar") do
              t(".scheduled", date: l(@scheduled, format: :short))
            end
          end

          def worked = mark(nil, "fa-regular fa-clock") { hours(@task.worked_seconds) }

          def worked? = !@task.in_progress? && @task.worked_seconds.positive?
        end
      end
    end
  end
end
