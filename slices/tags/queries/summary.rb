# frozen_string_literal: true

module Tags
  module Queries
    class Summary
      include Deps[
        "tasks.queries.tasks_by_tag",
        decision_queries: "decisions.repos.decision_queries",
        posts_by_tag: "posts.queries.by_tag",
        journal_entry_queries: "record.repos.journal_entry_queries",
        project_queries: "projects.repos.project_queries",
        tag_repo: "repos.tag_repo",
      ]

      def call(name)
        tags = tag_repo.named(name)
        return if tags.empty?

        Structs::Summary.new(
          name:, tags:, posts: posts_by_tag.call(name), projects: project_queries.by_tag(name),
          tasks: tasks_by_tag.call(name), journal_entries: journal_entry_queries.by_tag(name),
          decisions: decision_queries.by_tag(name),
        )
      end
    end
  end
end
