# frozen_string_literal: true

module Tasks
  module Operations
    class CreditAgents
      AGENT = Blog::Types::ContributorKind["agent"]
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      ISSUE_URL = "https://github.com/%s/issues/%s"

      include Deps[
        task_contributor_mutations: "repos.task_contributor_mutations",
        task_source_queries: "repos.task_source_queries",
      ]

      def call(repo, issues, agents)
        urls = issues.map { format(ISSUE_URL, repo, it) }
        task_ids = task_source_queries.task_ids_at(GITHUB, urls)
        rows = agents.map { { kind: AGENT, agent: it.fetch("agent"), model: it.fetch("model") } }

        task_contributor_mutations.add_missing(task_ids, rows)
      end
    end
  end
end
