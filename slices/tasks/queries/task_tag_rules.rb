# frozen_string_literal: true

module Tasks
  module Queries
    class TaskTagRules
      include Deps[task_tag_rule_repo: "repos.task_tag_rule_repo"]

      def call = task_tag_rule_repo.all
    end
  end
end
