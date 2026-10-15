# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class MenuPlan < Component
          CHECK = ContextMenu::CHECK
          PULL = "fa-solid fa-arrow-turn-up"
          TODAY = Blog::Types::TaskFilter["today"]

          prop :menu, Blog::Types::Instance(ContextMenu)
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :today, Blog::Types::Date
          prop :sprints, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            @menu.post(t(".pull"), action: act(:admin_move_task, filter: TODAY), icon: PULL) unless held == @today
            @menu.separator
            moves
            schedule
          end

          private

          def act(route, **) = path(route, id: @task.id, **)

          def held = @task.sprint&.sprint_date

          def move(list)
            here = !@task.ahead?(@today) && @task.place == list
            label = t(Helpers::TaskLists.title(list))

            @menu.post(label, action: act(:admin_move_task, filter: list), icon: (CHECK if here), disabled: here)
          end

          def moves
            @menu.sub(t(".move"), icon: "fa-solid fa-arrow-right-arrow-left") do
              Blog::Types::TaskFilter.each_value { move(it) }
            end
          end

          def schedule
            @menu.sub(t(".schedule"), icon: "fa-regular fa-calendar", hint: (short(held) if held && held != @today)) do
              sprint(t(".today"), @today)
              sprint(t(".tomorrow"), @today + 1)
              @sprints.each { sprint(t(".sprint"), it.sprint_date) }
              @menu.post(t(".unschedule"), action: act(:admin_schedule_task), icon: "fa-solid fa-xmark") if held
            end
          end

          def short(date) = l(date, format: :short)

          def sprint(label, date)
            fields = { sprint_on: date.iso8601 }

            @menu.post(label, action: act(:admin_schedule_task), fields:, hint: short(date),
                              icon: (CHECK if held == date))
          end
        end
      end
    end
  end
end
