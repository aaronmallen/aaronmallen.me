# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskRule < Operation
      include Deps[task_rule_repo: "repos.task_rule_repo"]

      def call(id) = step found(task_rule_repo.delete(id))
    end
  end
end
