# frozen_string_literal: true

module Tags
  module Queries
    class Summary
      include Deps[
        decision_queries: "decisions.repos.decision_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        project_queries: "projects.repos.project_queries",
        tag_repo: "repos.tag_repo",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(name)
        tags = tag_repo.named(name)
        return if tags.empty?

        Structs::Summary.new(
          name:, tags:, posts: post_queries.by_tag(name), projects: project_queries.by_tag(name),
          tasks: task_queries.by_tag(name), journal_entries: journal_entry_queries.by_tag(name),
          decisions: decision_queries.by_tag(name),
        )
      end
    end
  end
end
