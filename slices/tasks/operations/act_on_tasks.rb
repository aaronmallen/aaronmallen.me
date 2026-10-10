# frozen_string_literal: true

module Tasks
  module Operations
    class ActOnTasks < Blog::Operation
      CANCEL = Blog::Types::TaskBulkAction["cancel"]
      COMPLETE = Blog::Types::TaskBulkAction["complete"]
      FIELDS = %i[act ids tag to].freeze
      MOVE = Blog::Types::TaskBulkAction["move"]
      TAG = Blog::Types::TaskBulkAction["tag"]
      UNTAG = Blog::Types::TaskBulkAction["untag"]
      INPUTS = { MOVE => :to, TAG => :tag, UNTAG => :tag }.freeze

      include Deps[
        contract: "contracts.bulk_contract",
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        delete_task: "operations.delete_task",
        move_task: "operations.move_task",
        tag_task: "operations.tag_task",
        untag_task: "operations.untag_task",
      ]

      def call(params, at: Time.now)
        fields = step validate(params)
        operation = single(fields[:act])
        input = fields.values_at(*INPUTS[fields[:act]])

        each_record(fields[:ids]) { operation.call(it, *input, at:) }
      end

      private

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def single(act)
        case act
          when CANCEL then cancel_task
          when COMPLETE then complete_task
          when MOVE then move_task
          when TAG then tag_task
          when UNTAG then untag_task
          else delete_task
        end
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
