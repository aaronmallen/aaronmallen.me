# frozen_string_literal: true

module API
  module Endpoints
    class ReorderTask < TaskEndpoint
      APART = "task %s is not in task %s's list or sprint"
      EITHER = "give either direction or after_id, not both"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          after_id: Schema.nullable(Schema::ID).merge(
            description: "the task to follow, from the same list or sprint; null puts the task first",
          ),
          direction: { type: "string", enum: Tasks::DIRECTIONS, description: "move one place up or down" },
          id: Tasks::ID,
        },
        required: %w[id],
      }.freeze

      REPLY = Schema.widen(TaskEndpoint::REPLY, moved: Schema::BOOLEAN).freeze

      include Deps[place_task: "tasks.operations.place_task", reorder_task: "tasks.operations.reorder_task"]

      def handle(id:, **move)
        return invalid(ROOT => [EITHER]) unless move.size == 1

        move.key?(:direction) ? nudge(id, move[:direction]) : place(id, move[:after_id])
      end

      private

      def moved(result, id)
        case result
        in Success(*) then answered(id, moved: true)
        in Failure(:not_moved | :not_placed) then answered(id, moved: false)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Wording::UNSAVED)
        end
      end

      def nudge(id, direction) = moved(reorder_task.call(id, direction), id)

      def place(id, after_id)
        case place_task.call(id, after_id)
        in Failure(:after_not_found) then not_found(Tasks.missing(after_id))
        in Failure(:apart) then invalid(after_id: [format(APART, after_id, id)])
        in result then moved(result, id)
        end
      end
    end
  end
end
