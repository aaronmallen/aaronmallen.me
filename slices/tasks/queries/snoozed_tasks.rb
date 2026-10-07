# frozen_string_literal: true

module Tasks
  module Queries
    class SnoozedTasks
      include Deps[task_source_repo: "repos.task_source_repo"]

      def call = task_source_repo.snoozed_tasks
    end
  end
end
