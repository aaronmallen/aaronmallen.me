# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class UpcomingSprints < Component
          NEXT = Blog::Types::TaskFilter["next"]
          TAB = Blog::Types::TaskTab["upcoming"]

          prop :planned, Blog::Types::Array.of(Blog::Types::Hash)
          prop :today, Blog::Types::Date
          prop :waiting, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            plan_form
            return Empty { t(".none") } if @planned.empty?

            div(class: "cols") { @planned.each { sprint_card(it[:sprint], it[:tasks]) } }
          end

          private

          def drop_attributes(sprint)
            {
              action: path(:admin_drop_sprint, id: sprint.id),
              data: { confirm: t(".confirm_drop", date: l(sprint.sprint_date, format: :medium)) },
            }
          end

          def drop_form(sprint)
            Form(**drop_attributes(sprint)) do
              Button(variant: :warn, type: "submit", small: true, icon: "fa-regular fa-trash-can") { t(".drop") }
            end
          end

          def plan_form
            Form(action: path(:admin_plan_sprint), class: "sprint-plan") do
              label(class: "sprint-plan-label", for: "sprint-on") { t(".open_for") }
              Input(type: "date", id: "sprint-on", name: "sprint_on", min: tomorrow, value: tomorrow)
              Button(type: "submit", small: true, icon: "fa-solid fa-plus") { t(".open") }
              span(class: "sprint-plan-note") { t(".note") }
            end
          end

          def pull(sprint)
            details(class: "sprint-pull") do
              summary do
                Icon("fa-solid fa-chevron-right")
                plain t(".pull")
              end
              waiting(sprint)
            end
          end

          def pull_form(task, sprint)
            Form(action: path(:admin_schedule_task, id: task.id)) do
              input(type: "hidden", name: "sprint_on", value: sprint.sprint_date.iso8601)
              Button(type: "submit", small: true, aria: { label: t(".pull_task", task: task.title) }) do
                IconLabel(icon: "fa-solid fa-arrow-turn-up") { t(".pull_in") }
              end
            end
          end

          def relative(date)
            days = (date - @today).to_i

            days == 1 ? t(".tomorrow") : t(".in_days", count: days)
          end

          def rows(sprint, tasks)
            return Empty { t(".empty") } if tasks.empty?

            tasks.each do |task|
              Row(task:, filter: NEXT, tab: TAB, today: @today, scheduled: sprint.sprint_date)
            end
          end

          def sprint_card(sprint, tasks)
            open = tasks.reject(&:closed?)

            date = sprint.sprint_date

            Card(title: relative(date), data: { key_list: true }) do |card|
              card.side { sprint_side(sprint, open) }
              rows(sprint, open)
              QuickAdd(filter: NEXT, sprint_on: date, placeholder: t(".add_to", date: l(date, format: :short)))
              pull(sprint)
            end
          end

          def sprint_side(sprint, open)
            span(class: "card-note") { dotted(l(sprint.sprint_date, format: :weekday), t(".count", count: open.size)) }
            drop_form(sprint)
          end

          def tomorrow = (@today + 1).iso8601

          def waiting(sprint)
            return Empty { t(".nothing_waiting") } if @waiting.empty?

            @waiting.each { |task| ListItem(title: task.title, hover: true) { pull_form(task, sprint) } }
          end
        end
      end
    end
  end
end
