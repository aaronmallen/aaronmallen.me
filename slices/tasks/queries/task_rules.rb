# frozen_string_literal: true

module Tasks
  module Queries
    class TaskRules
      include Deps[task_rule_repo: "repos.task_rule_repo"]

      def call = task_rule_repo.all

      def projects = task_rule_repo.project_choices
    end
  end
end
