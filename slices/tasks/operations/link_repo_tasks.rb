# frozen_string_literal: true

module Tasks
  module Operations
    class LinkRepoTasks
      include Deps[task_rule_mutations: "repos.task_rule_mutations", task_rule_queries: "repos.task_rule_queries"]

      def call(project, was: nil)
        repo = project.repo
        return project if repo.nil? || repo == was

        task_rule_mutations.link_projects(task_rule_queries.repo_task_ids(repo), [project.id])

        project
      end
    end
  end
end
