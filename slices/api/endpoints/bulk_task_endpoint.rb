# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkTaskEndpoint < Endpoint
      CLOSED = "task %s is already done or canceled"
      FIELDS = { to: :list }.freeze
      REPLY = Schema.object({ tasks: Schema.list(Serializers::Task.reference) }).freeze
      UNCHANGED = "could not change task %s"

      include Deps[act_on_tasks: "tasks.operations.act_on_tasks", task_by_id: "tasks.queries.task_by_id"]

      private

      def acted(ids, **input)
        case act_on_tasks.call({ act: self.class::ACT, ids:, **input })
        in Success[*tasks] then Success(tasks: answered(ids.uniq, tasks))
        in Failure[:record, id, reason] then refused(id, reason)
        in Failure[:invalid, errors] then rejected(errors)
        else failed(Tasks::UNSAVED)
        end
      end

      def answered(ids, _tasks) = serialized(Serializers::Task, ids.map { task_by_id.call(it) })

      def refused(id, reason)
        case reason
        when :not_found then invalid(ids: [Tasks.missing(id)])
        when :closed then invalid(ids: [format(CLOSED, id)])
        else failed(format(UNCHANGED, id))
        end
      end

      def rejected(errors)
        complaints = Tasks.complaints(flat(errors).transform_keys { FIELDS.fetch(it, it) })

        Failure(Refusal.invalid(complaints, message: Tasks.summary(complaints)))
      end
    end
  end
end
