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
              @task.tags.each { Tag(tag: it, project_key: @task.project_key_for(it)) }
              worked if worked?
              comments
              blocking
              Closed(task: @task) if @task.closed?
            end
          end

          private

          def blocking = related(:sand, "fa-solid fa-arrow-right-long", ".blocking", @task.links.select(&:blocking?))

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
            span(class: ["task-mark", :blue]) do
              Icon("fa-solid fa-circle-play")
              next plain(t(".in_progress")) unless @task.running_session || @task.tracked_seconds.positive?

              Tracked(task: @task, text: t(".in_progress_for", span: Tracked::SPAN))
            end
          end

          def mark(tone, icon, title: nil, &)
            span(class: ["task-mark", tone], title:) do
              Icon(icon)
              plain(yield)
            end
          end

          def marks
            return if @task.closed?

            related(:pink, "fa-solid fa-lock", ".blocked_by", @task.links.select(&:blocker?))
            carried if @task.carried_count.positive?
            return unless @scheduled

            mark(:orange, "fa-regular fa-calendar") do
              t(".scheduled", date: l(@scheduled, format: :short))
            end
          end

          def related(tone, icon, key, links)
            return if links.empty?

            mark(tone, icon, title: links.map { it.task.title }.join("\n")) { t(key, count: links.size) }
          end

          def worked = mark(nil, "fa-regular fa-clock") { hours(@task.worked_seconds) }

          def worked? = !@task.in_progress? && @task.worked_seconds.positive?
        end
      end
    end
  end
end
