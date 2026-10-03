# frozen_string_literal: true

module Tasks
  module Relations
    class WorkSessions < Blog::DB::Relation
      CLOSED_TASK = { Sequel[:tasks][:id] => Sequel[:closed][:task_id] }.freeze
      WORKED = Sequel[:tasks][:worked_seconds] + Sequel[:closed][:seconds]

      schema :work_sessions, infer: true do
        associations do
          belongs_to :task
        end
      end

      def close(task_ids, at)
        closed = tasks.dataset.unordered.with(:closed, ending(task_ids, at)).from(:tasks, :closed)

        closed.where(CLOSED_TASK).update(worked_seconds: WORKED)
      end

      def for_task(task_id) = where(task_id:)

      def open(task_id, at) = running.for_task(task_id).exist? || command(:create).call(task_id:, started_at: at)

      def running = where(ended_at: nil)

      def split(task_ids, at)
        close(task_ids, at)
        command(:create, result: :many).call(task_ids.map { { task_id: it, started_at: at } })
      end

      private

      def ending(task_ids, at)
        ended = Sequel.function(:greatest, at, :started_at)

        found = running.where(task_id: task_ids).dataset.unordered.returning(:task_id, seconds(ended).as(:seconds))

        found.with_sql(:update_sql, ended_at: ended, updated_at: Sequel::CURRENT_TIMESTAMP)
      end

      def seconds(ended) = Sequel.function(:floor, Sequel.extract(:epoch, ended - :started_at)).cast(Integer)
    end
  end
end
