# frozen_string_literal: true

module Tasks
  module Operations
    class SettleTask < Blog::Operation
      COMPLETED = Blog::Types::TaskSourceState["completed"]
      OPEN = Blog::Types::TaskSourceState["open"]
      STARTED = Blog::Types::TaskSourceState["started"]

      include Deps[
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        reopen_task: "operations.reopen_task",
        start_task: "operations.start_task",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(task, from:, to:, at:, history: nil)
        task, from = replay(task, from, history)

        from == to ? task : settle(task, from, to, at)
      end

      private

      def close(task, at) = task.closed? ? Success(task) : cancel_task.call(task.id, at:)

      def finish(task, at) = reopen(task, nil, at).bind { complete_task.call(task.id, at:) }

      def reopen(task, was, at)
        return Success(task) unless task.closed? || (was == STARTED && task.in_progress?)

        reopen_task.call(task.id, at:)
      end

      def replay(task, from, history)
        history.to_a.reduce([task, from]) do |(current, _), change|
          [settle(current, *change.values_at(:from, :to, :at), replayed: true), change[:to]]
        end
      end

      def settle(task, from, to, at, replayed: false)
        case to
          when OPEN then reopen(task, from, at)
          when STARTED then start(task, at, replayed)
          when COMPLETED then task.done? ? Success(task) : finish(task, at)
          else close(task, at)
        end.value_or(task)
      end

      def start(task, at, replayed)
        return start_task.call(task.id, at:, seen: false) unless task.in_progress?

        work_session_mutations.rewind(task.id, at) if replayed
        Success(task)
      end
    end
  end
end
