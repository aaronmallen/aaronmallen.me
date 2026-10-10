# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Controls < Component
          COMPLETE = "x"
          LEFT = "fa-solid fa-arrow-left"
          MOVE = "m"
          RIGHT = "fa-solid fa-arrow-right"
          TODAY, NEXT, SOMEDAY, EXTERNAL = %w[today next someday external].map { Blog::Types::TaskFilter[it] }
          MOVES = {
            TODAY => [[NEXT, RIGHT, MOVE]],
            NEXT => [[TODAY, LEFT, MOVE], [SOMEDAY, RIGHT, nil]],
            SOMEDAY => [[NEXT, LEFT, MOVE]],
            EXTERNAL => [[TODAY, LEFT, MOVE]],
          }.freeze
          START = "s"
          KEY_LABELS = { COMPLETE => ".keys.complete", MOVE => ".keys.move", START => ".keys.start" }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :moves, Blog::Types::Bool, default: true
          prop :row, Blog::Types::Bool, default: false

          def view_template
            @task.closed? ? reopen : progress
            moves if @moves && !@task.closed?
          end

          private

          def cancel
            data = { confirm: t(".confirm_cancel", task: @task.title) }

            change(:admin_cancel_task, "fa-solid fa-ban", t(".cancel"), data:)
          end

          def change(route, icon, label, variant: nil, data: nil, key: nil)
            Form(action: path(route, id: @task.id), data:) do
              origin_fields
              Button(type: "submit", variant:, small: true, title: label, **keyed(key, label:), icon:)
            end
          end

          def complete
            Form(action: path(:admin_complete_task, id: @task.id), data: { task_act: "complete" }) do
              origin_fields
              details(class: "task-complete") do
                complete_toggle
                div(class: "task-complete-panel") do
                  worked_fields
                  Button(type: "submit", variant: :pri, small: true) { done_label }
                end
              end
            end
          end

          def complete_toggle
            return summary(class: "bt pri sm", **keyed(COMPLETE)) { done_label } unless @row

            label = t(".complete")
            summary(class: "bt sm", title: label, **keyed(COMPLETE, label:)) do
              Icon("fa-solid fa-check")
              span(class: "sr-only") { label }
            end
          end

          def done_label
            IconLabel(icon: "fa-solid fa-check") { t(".complete") }
          end

          def keyed(key, **aria)
            return { aria: } unless @row && key

            { aria: { **aria, keyshortcuts: key }, data: { key:, key_label: t(KEY_LABELS.fetch(key)) } }
          end

          def move(place, icon, key:)
            list = t(Helpers::TaskLists.title(place))
            label = t(".move", list:)

            Form(action: path(:admin_move_task, id: @task.id, filter: place), data: move_confirm(list)) do
              origin_field
              Button(type: "submit", small: true, title: label, **keyed(key, label:), icon:)
            end
          end

          def move_confirm(list)
            { confirm: t(".confirm_move", task: @task.title, list:) } if running?
          end

          def moves = MOVES.fetch(@task.place).each { |place, side, key| move(place, side, key:) }

          def origin_field = input(type: "hidden", name: "origin", value: @origin)

          def origin_fields = HiddenFields(values: { filter: @filter, origin: @origin })

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

          def start
            change(:admin_start_task, "fa-solid fa-play", t(".start"), data: { task_act: "start" }, key: START)
          end

          def stop = change(:admin_stop_task, "fa-solid fa-pause", t(".stop"), data: { task_act: "pause" })

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
