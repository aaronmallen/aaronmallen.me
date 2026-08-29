# frozen_string_literal: true

module Tasks
  module Queries
    class TaskTypes
      include Deps[task_type_repo: "repos.task_type_repo"]

      def call = task_type_repo.all
    end
  end
end
