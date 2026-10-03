# frozen_string_literal: true

module Tasks
  module Operations
    class ActOnTasks < Blog::Operation
      CANCEL = Blog::Types::TaskBulkAction["cancel"]
      COMPLETE = Blog::Types::TaskBulkAction["complete"]
      FIELDS = %i[act ids].freeze

      include Deps[
        contract: "contracts.bulk_contract",
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        delete_task: "operations.delete_task",
      ]

      def call(params, at: Time.now)
        fields = step validate(params)
        operation = single(fields[:act])

        transaction do
          fields[:ids].map { |id| step(operation.call(id, at:).alt_map { [:record, id, it] }) }
        end
      end

      private

      def form(params) = FIELDS.to_h { [it, params[it]] }

      def single(act)
        case act
        when CANCEL then cancel_task
        when COMPLETE then complete_task
        else delete_task
        end
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
