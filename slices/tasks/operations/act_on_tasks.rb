# frozen_string_literal: true

module Tasks
  module Operations
    class ActOnTasks < Blog::Operation
      CANCEL = Blog::Types::TaskBulkAction["cancel"]
      COMPLETE = Blog::Types::TaskBulkAction["complete"]
      DELETE = Blog::Types::TaskBulkAction["delete"]
      MOVE = Blog::Types::TaskBulkAction["move"]
      TAG = Blog::Types::TaskBulkAction["tag"]
      UNTAG = Blog::Types::TaskBulkAction["untag"]
      INPUTS = { MOVE => :to }.freeze
      TAGGING = { TAG => :add, UNTAG => :remove }.freeze

      include Deps[
        contract: "contracts.bulk_contract",
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        delete_task: "operations.delete_task",
        move_task: "operations.move_task",
        task_event_mutations: "repos.task_event_mutations",
        task_queries: "repos.task_queries",
        task_tag_mutations: "repos.task_tag_mutations",
      ]

      def call(params, at: Time.now)
        fields = step validate(params)
        return retag(fields, at) if TAGGING.key?(fields[:act])

        operation = single(fields[:act])
        input = fields.values_at(*INPUTS[fields[:act]])

        each_record(fields[:ids]) { operation.call(it, *input, at:) }
      end

      private

      def every_task(ids)
        found = task_queries.ids_of(ids).to_h { [it.id, it] }
        missing = ids.find { !found.key?(it) }

        missing ? Failure([:record, missing, :not_found]) : Success(found.values_at(*ids))
      end

      def retag(fields, at)
        ids = fields[:ids]
        tasks = step every_task(ids)

        task_event_mutations.track(ids, at) { task_tag_mutations.public_send(TAGGING[fields[:act]], ids, fields[:tag]) }
        tasks
      end

      def single(act)
        case act
          when CANCEL then cancel_task
          when COMPLETE then complete_task
          when MOVE then move_task
          when DELETE then delete_task
          else raise ArgumentError, "no task operation for #{act}"
        end
      end
    end
  end
end
