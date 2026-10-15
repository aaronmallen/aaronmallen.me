# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Controls < Component
          LEFT = "fa-solid fa-arrow-left"
          MOVE = "m"
          RIGHT = "fa-solid fa-arrow-right"
          TODAY, NEXT, SOMEDAY, EXTERNAL = %w[today next someday external].map { Blog::Types::TaskFilter[it] }
          AHEAD = :ahead
          MOVES = {
            AHEAD => [[TODAY, LEFT, MOVE], [NEXT, RIGHT, nil]],
            TODAY => [[NEXT, RIGHT, MOVE]],
            NEXT => [[TODAY, LEFT, MOVE], [SOMEDAY, RIGHT, nil]],
            SOMEDAY => [[NEXT, LEFT, MOVE]],
            EXTERNAL => [[TODAY, LEFT, MOVE]],
          }.freeze
          START = "s"
          KEY_LABELS = { MOVE => ".keys.move", START => ".keys.start" }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :moves, Blog::Types::Bool, default: true
          prop :row, Blog::Types::Bool, default: false
          prop :ahead, Blog::Types::Bool, default: false

          def view_template
            @task.closed? ? reopen : progress
            moves if @moves && !@task.closed?
          end

          private

          def cancel
            data = { confirm: t(".confirm_cancel", task: @task.title) }

            change(:admin_cancel_task, "fa-solid fa-ban", t(".cancel"), data:)
          end

          def change(route, icon, label, variant: nil, data: Blog::Constants::EMPTY_HASH, key: nil)
            Form(action: path(route, id: @task.id), data: { morph: true, **data }) do
              origin_fields
              Button(type: "submit", variant:, small: true, label:, **keyed(key), icon:)
            end
          end

          def complete = CompleteForm(task: @task, filter: @filter, origin: @origin, compact: @row, keyed: @row)

          def keyed(key)
            return Blog::Constants::EMPTY_HASH unless @row && key

            { aria: { keyshortcuts: key }, data: { key:, key_label: t(KEY_LABELS.fetch(key)) } }
          end

          def move(place, icon, key:)
            list = t(Helpers::TaskLists.title(place))
            label = t(".move", list:)
            data = { morph: true, **move_confirm(list) }

            Form(action: path(:admin_move_task, id: @task.id, filter: place), data:) do
              origin_field
              Button(type: "submit", small: true, label:, **keyed(key), icon:)
            end
          end

          def move_confirm(list)
            running? ? { confirm: t(".confirm_move", task: @task.title, list:) } : Blog::Constants::EMPTY_HASH
          end

          def moves = MOVES.fetch(@ahead ? AHEAD : @task.place).each { |place, side, key| move(place, side, key:) }

          def origin_field = input(type: "hidden", name: "origin", value: @origin)

          def origin_fields = HiddenFields(values: { filter: @filter, origin: @origin })

          def progress
            complete if @row || running?
            running? ? stop : start
            cancel
          end

          def reopen = change(:admin_reopen_task, "fa-solid fa-rotate-left", t(".reopen"))

          def running? = @task.in_progress? && @task.in_sprint?

          def start
            change(:admin_start_task, "fa-solid fa-play", t(".start"), data: { task_act: "start" }, key: START)
          end

          def stop = change(:admin_stop_task, "fa-solid fa-pause", t(".stop"), data: { task_act: "pause" })
        end
      end
    end
  end
end
