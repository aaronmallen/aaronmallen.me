# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskRule < Operation
      include Deps[task_rule_mutations: "repos.task_rule_mutations"]

      def call(id) = step found(task_rule_mutations.delete(id))
    end
  end
end
