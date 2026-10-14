# frozen_string_literal: true

module Tasks
  module Operations
    class SetTasksColumn < Blog::Operation
      include Deps["operations.set_task_column", contract: "contracts.column_contract"]

      def call(params)
        fields = step validated(contract.call(every_field(params)))

        each_record(fields[:ids]) { set_task_column.call(it, fields[:to]) }
      end
    end
  end
end
