# frozen_string_literal: true

module Tasks
  module Queries
    class UnseenTaskCount
      include Deps[task_source_repo: "repos.task_source_repo"]

      def call = task_source_repo.unseen_task_count
    end
  end
end
