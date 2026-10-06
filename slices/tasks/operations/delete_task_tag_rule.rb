# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskTagRule < Blog::Operation
      include Deps[task_tag_rule_repo: "repos.task_tag_rule_repo"]

      def call(id) = step found(task_tag_rule_repo.delete(id))
    end
  end
end
