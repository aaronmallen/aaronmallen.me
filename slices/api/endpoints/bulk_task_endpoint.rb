# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkTaskEndpoint < Endpoint
      FIELDS = { to: :list }.freeze
      REPLY = Schema.object({ tasks: Schema.list(Serializers::Task.reference) }).freeze
      UNCHANGED = "could not change task %s"

      include Deps[act_on_tasks: "tasks.operations.act_on_tasks", task_queries: "tasks.repos.task_queries"]

      private

      def acted(ids, **input)
        case act_on_tasks.call({ act: self.class::ACT, ids:, **input })
        in Success[*tasks] then Success(tasks: answered(ids.uniq, tasks))
        in Failure[:record, id, reason] then refused(id, reason)
        in Failure[:invalid, errors] then rejected(keyed(errors), Tasks::COMPLAINTS)
        else failed(Wording::UNSAVED)
        end
      end

      def answered(ids, _tasks) = serialized(Serializers::Task, ids.map { task_queries.detailed(it) })

      def keyed(errors) = flat(errors).transform_keys { FIELDS.fetch(it, it) }

      def refused(id, reason)
        case reason
        when :not_found then invalid(ids: [Wording.missing("task", id)])
        when :closed then invalid(ids: [format(Tasks::CLOSED, id)])
        else failed(format(UNCHANGED, id))
        end
      end
    end
  end
end
