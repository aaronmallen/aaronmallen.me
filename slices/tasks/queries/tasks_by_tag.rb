# frozen_string_literal: true

module Tasks
  module Queries
    class TasksByTag
      include Deps[task_repo: "repos.task_repo"]

      def call(tag) = task_repo.by_tag(tag)
    end
  end
end
