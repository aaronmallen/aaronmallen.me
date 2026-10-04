# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskTagRule < Blog::Operation
      include Deps[task_tag_rule_repo: "repos.task_tag_rule_repo"]

      def call(id) = step deleted(task_tag_rule_repo.delete(id))

      private

      def deleted(rule) = rule ? Success(rule) : Failure(:not_found)
    end
  end
end
