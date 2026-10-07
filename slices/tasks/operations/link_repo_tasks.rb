# frozen_string_literal: true

module Tasks
  module Operations
    class LinkRepoTasks < Operation
      include Deps[task_rule_repo: "repos.task_rule_repo"]

      def call(project, was: nil)
        repo = project.repo
        task_rule_repo.link_projects(task_rule_repo.repo_task_ids(repo), [project.id]) unless repo.nil? || repo == was

        project
      end
    end
  end
end
