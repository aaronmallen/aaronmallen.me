# frozen_string_literal: true

module Tasks
  module Operations
    class AddRepoRule
      GITHUB = Blog::Types::TaskSourceProvider["github"]

      include Deps[
        save_task_rule: "operations.save_task_rule",
        task_rule_mutations: "repos.task_rule_mutations",
        task_rule_queries: "repos.task_rule_queries",
      ]

      def call(project, was: nil)
        repo = project.repo
        return project if repo.nil? || repo == was

        rule = task_rule_queries.by_pattern(GITHUB, repo)
        if rule.nil? then save_task_rule.call({ pattern: repo, provider: GITHUB, tags: "", projects: [project.id] })
        elsif rule.projects.empty? then claim(rule, project.id)
        end

        project
      end

      private

      def claim(rule, project_id)
        task_rule_mutations.replace_projects(rule.id, [project_id])
        task_rule_mutations.fill_project(task_rule_queries.matching_task_ids(rule), project_id)
      end
    end
  end
end
