# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TimeWorked < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :forms, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            Field(label: t(".label", span: Blog::Helpers::Figures.hours(@task.tracked_seconds))) do
              if sessions.empty? then Hint { t(".empty") }
              else ol(class: "task-sessions") { sessions.each { session(it) } }
              end
              TotalForm(task: @task, totaling: @forms[:totaling], tab: @tab, origin: @origin)
            end
          end

          private

          def ended(entry)
            return plain(t(".now")) if entry.running?

            Moment(at: entry.ended_at, format: :clock)
          end

          def length(entry)
            return Pill(color: :blue) { t(".running") } if entry.running?

            plain Blog::Helpers::Figures.hours(entry.seconds)
          end

          def session(entry)
            li(class: "task-session", id: "task-session-#{entry.source_id}") do
              span(class: "task-session-span") do
                Moment(at: entry.occurred_at, format: :short)
                plain "–"
                ended(entry)
              end
              span(class: "task-session-length") { length(entry) }
              SessionActs(task: @task, entry:, timing: @forms[:timing], tab: @tab, origin: @origin)
            end
          end

          def sessions = @sessions ||= @entries.select(&:session?)
        end
      end
    end
  end
end
