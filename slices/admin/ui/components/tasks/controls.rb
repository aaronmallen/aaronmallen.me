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
            change(:admin_cancel_task, :ban, t(".cancel"), confirm: t(".confirm_cancel", task: @task.title))
          end

          def change(route, icon, label, confirm: nil, data: Blog::Constants::EMPTY_HASH, key: nil)
            ButtonForm(
              action: path(route, id: @task.id), label:, icon:, icon_only: true, morph: true, confirm:, data:,
              hidden: { filter: @filter, origin: @origin }, button: keyed(key),
            )
          end

          def complete = CompleteForm(task: @task, filter: @filter, origin: @origin, compact: @row, keyed: @row)

          def keyed(key)
            return Blog::Constants::EMPTY_HASH unless @row && key

            { aria: { keyshortcuts: key }, data: { key:, key_label: t(KEY_LABELS.fetch(key)) } }
          end

          def move(place, icon, key:)
            list = t(Helpers::TaskLists.title(place))
            confirm = t(".confirm_move", task: @task.title, list:) if running?

            ButtonForm(
              action: path(:admin_move_task, id: @task.id, filter: place), label: t(".move", list:), icon:,
              icon_only: true, morph: true, confirm:, hidden: { origin: @origin }, button: keyed(key),
            )
          end

          def moves = MOVES.fetch(@ahead ? AHEAD : @task.place).each { |place, side, key| move(place, side, key:) }

          def progress
            complete if @row || running?
            running? ? stop : start
            cancel
          end

          def reopen = change(:admin_reopen_task, :restore, t(".reopen"))

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
