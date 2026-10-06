# frozen_string_literal: true

module Tasks
  module Operations
    class CreditAgents
      AGENT = Blog::Types::ContributorKind["agent"]
      GITHUB = Blog::Types::TaskSourceProvider["github"]

      include Deps[
        task_contributor_repo: "repos.task_contributor_repo",
        task_source_repo: "repos.task_source_repo",
      ]

      def call(repo, issues, agents)
        urls = issues.map { format(Blog::Constants::GITHUB_ISSUE_URL, repo, it) }
        task_ids = task_source_repo.task_ids_at(GITHUB, urls)
        rows = agents.map { { kind: AGENT, agent: it.fetch("agent"), model: it.fetch("model") } }

        task_contributor_repo.add_missing(task_ids, rows)
      end
    end
  end
end
