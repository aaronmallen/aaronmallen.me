# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskColumn < Blog::Operation
      CANCELED = Blog::Types::TaskColumn["canceled"]
      DONE = Blog::Types::TaskColumn["done"]
      IN_PROGRESS = Blog::Types::TaskColumn["in_progress"]
      OPEN = Blog::Types::TaskStatus["open"]

      include Deps[
        "operations.cancel_task",
        "operations.complete_task",
        "operations.reopen_task",
        "operations.stage_task",
        "operations.start_task",
        task_queries: "repos.task_queries",
      ]

      def call(id, column)
        task = step found(task_queries.by_id(id))
        transaction { move(task, column) } unless task.board_column == column
        column
      end

      private

      def close(task, operation)
        step reopen_task.call(task.id) if task.closed?
        step operation.call(task.id)
      end

      def move(task, column)
        case column
          when IN_PROGRESS then step start_task.call(task.id)
          when DONE then close(task, complete_task)
          when CANCELED then close(task, cancel_task)
          else stage(task, column)
        end
      end

      def stage(task, column)
        step reopen_task.call(task.id) unless task.status == OPEN
        step stage_task.call(task.id, column)
      end
    end
  end
end
