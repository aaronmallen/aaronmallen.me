# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Controls < Component
          EXTERNAL = Blog::Types::TaskFilter["external"]
          LEFT = "fa-solid fa-arrow-left"
          LISTS = {
            Blog::Types::TaskFilter["today"] => ".lists.today",
            Blog::Types::TaskFilter["next"] => ".lists.next",
            Blog::Types::TaskFilter["someday"] => ".lists.someday",
          }.freeze
          ORIGIN = Blog::Types::TaskOrigin["tasks"]
          PLACES = LISTS.keys.freeze
          RIGHT = "fa-solid fa-arrow-right"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::String, default: ORIGIN
          prop :moves, Blog::Types::Bool, default: true

          def view_template
            @task.closed? ? reopen : progress
            moves if @moves && !@task.closed?
          end

          private

          def cancel
            data = { confirm: t(".confirm_cancel", task: @task.title), confirm_styled: true }

            change(:admin_cancel_task, "fa-solid fa-ban", t(".cancel"), data:)
          end

          def change(route, icon, label, variant: nil, data: nil)
            Form(action: path(route, id: @task.id), data:) do
              origin_fields
              Button(type: "submit", variant:, small: true, title: label, aria: { label: }) do
                i(class: icon, aria: { hidden: "true" })
              end
            end
          end

          def complete
            Form(action: path(:admin_complete_task, id: @task.id), data: { task_act: "complete" }) do
              origin_fields
              details(class: "task-complete") do
                summary(class: "btn pri sm") { done_label }
                div(class: "task-complete-panel") do
                  worked_fields
                  Button(type: "submit", variant: :pri, small: true) { done_label }
                end
              end
            end
          end

          def done_label
            i(class: "fa-solid fa-check", aria: { hidden: "true" })
            span { t(".complete") }
          end

          def move(place, icon)
            list = t(LISTS.fetch(place))
            label = t(".move", list:)

            Form(action: path(:admin_move_task, id: @task.id, filter: place), data: move_confirm(list)) do
              origin_field
              Button(type: "submit", small: true, title: label, aria: { label: }) do
                i(class: icon, aria: { hidden: "true" })
              end
            end
          end

          def move_confirm(list)
            { confirm: t(".confirm_move", task: @task.title, list:), confirm_styled: true } if running?
          end

          def moves
            return move(PLACES.first, LEFT) if @task.place == EXTERNAL

            here = PLACES.index(@task.place)

            move(PLACES[here - 1], LEFT) if here.positive?
            move(PLACES[here + 1], RIGHT) if here < PLACES.size - 1
          end

          def origin_field = input(type: "hidden", name: "origin", value: @origin)

          def origin_fields
            input(type: "hidden", name: "filter", value: @filter)
            origin_field
          end

          def progress
            running? ? running : start
            cancel
          end

          def reopen = change(:admin_reopen_task, "fa-solid fa-rotate-left", t(".reopen"))

          def running
            complete
            stop
          end

          def running? = @task.in_progress? && @task.in_sprint?

          def start = change(:admin_start_task, "fa-solid fa-play", t(".start"), data: { task_act: "start" })

          def stop = change(:admin_stop_task, "fa-solid fa-pause", t(".stop"))

          def worked_fields
            tracked = @task.tracked_seconds

            input(type: "hidden", name: "worked[tracked]", value: tracked)
            fieldset(class: "task-complete-ask") do
              legend { t(".ask") }
              WorkedFields(name: "worked", scope: "task-#{@task.id}-worked", seconds: tracked)
            end
          end
        end
      end
    end
  end
end
