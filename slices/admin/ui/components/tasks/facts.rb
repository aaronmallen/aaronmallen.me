# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Facts < Component
          AGENT = "fa-solid fa-robot"
          OWNER = "fa-regular fa-user"

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            dl(class: "task-facts") do
              filing
              dates
              tallies
            end
          end

          private

          def credit(credit)
            return Pill(icon: OWNER) { t(".owner") } unless credit[:agent]

            Pill(icon: AGENT) { t(".agent", **credit.slice(:agent, :model)) }
          end

          def credits = span(class: "task-fact-pills") { @task.credits.each { credit(it) } }

          def dates
            { ".created" => @task.created_at, ".updated" => @task.updated_at, ".completed" => @task.completed_at }
              .each { |key, at| fact(key) { Moment(at:) } if at }
          end

          def fact(label_key, &)
            div(class: "task-fact") do
              dt { t(label_key) }
              dd(&)
            end
          end

          def filing
            fact(".list") { t(Helpers::TaskLists.name(@task.place)) }
            fact(".sprint") { sprint_day }
            fact(".tags") { tags }
            fact(".contributors") { credits }
          end

          def sprint_day
            return Hint(inline: true) { t(".unscheduled") } unless @task.sprint

            l(@task.sprint.sprint_date, format: :medium)
          end

          def tags
            return Hint(inline: true) { t(".no_tags") } if @task.tags.empty?

            span(class: "task-fact-pills") { @task.tags.each { Tag(tag: it) } }
          end

          def tallies
            fact(".carried") { t(".carried_count", count: @task.carried_count) }
            fact(".worked") { Blog::Helpers::Figures.hours(@task.worked_seconds) }
          end
        end
      end
    end
  end
end
