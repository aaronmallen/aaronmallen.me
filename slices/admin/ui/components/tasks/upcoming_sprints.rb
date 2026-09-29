# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class UpcomingSprints < Component
          CHIP_LIMIT = 8
          NEXT = Blog::Types::TaskFilter["next"]
          TAB = Blog::Types::TaskTab["upcoming"]
          TITLE_LIMIT = 42

          prop :planned, Blog::Types::Array.of(Blog::Types::Hash)
          prop :today, Blog::Types::Date
          prop :waiting, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            plan_card
            @planned.each { sprint_card(it[:sprint], it[:tasks]) }
            Empty { t(".none") } if @planned.empty?
          end

          private

          def chip(task, sprint)
            Form(action: path(:admin_schedule_task, id: task.id)) do
              input(type: "hidden", name: "sprint_on", value: sprint.sprint_date.iso8601)
              button(type: "submit", class: "chip-btn", aria: { label: t(".pull_task", task: task.title) }) do
                i(class: "fa-solid fa-plus", aria: { hidden: "true" })
                span { shorten(task.title) }
              end
            end
          end

          def chips(sprint)
            return if @waiting.empty?

            div(class: "sprint-pull") do
              p(class: "sprint-pull-head") { t(".pull") }
              div(class: "sprint-chips") { @waiting.first(CHIP_LIMIT).each { chip(it, sprint) } }
            end
          end

          def drop_attributes(sprint)
            {
              action: path(:admin_drop_sprint, id: sprint.id),
              data: { confirm: t(".confirm_drop", date: l(sprint.sprint_date, format: :medium)) },
            }
          end

          def drop_form(sprint)
            Form(**drop_attributes(sprint)) do
              Button(variant: :warn, type: "submit", small: true) { t(".drop") }
            end
          end

          def plan_card
            Card(label: t(".label"), title: t(".title")) do |card|
              card.side { span(class: "sprint-note") { t(".planned", count: @planned.size) } }
              plan_form
              Hint { t(".note") }
            end
          end

          def plan_form
            Form(action: path(:admin_plan_sprint), class: "sprint-plan") do
              label(class: "sr-only", for: "sprint-on") { t(".date") }
              Input(type: "date", id: "sprint-on", name: "sprint_on", min: tomorrow, value: tomorrow)
              Button(variant: :pri, type: "submit") { t(".open") }
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

          def shorten(title) = Blog::Truncation.cut(title, keep: TITLE_LIMIT)

          def sprint_card(sprint, tasks)
            open = tasks.reject(&:closed?)

            Card(label: relative(sprint.sprint_date), title: l(sprint.sprint_date, format: :weekday)) do |card|
              card.side { sprint_side(sprint, open) }
              rows(sprint, open)
              chips(sprint)
            end
          end

          def sprint_side(sprint, open)
            span(class: "sprint-note") { t(".count", count: open.size) }
            drop_form(sprint)
          end

          def tomorrow = (@today + 1).iso8601
        end
      end
    end
  end
end
