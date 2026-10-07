# frozen_string_literal: true

module Tasks
  module Operations
    class UnlinkTask < Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, other_id)
        step affected(task_repo.unlink(id, other_id))

        task_repo.by_id(id)
      end
    end
  end
end
