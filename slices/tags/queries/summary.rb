# frozen_string_literal: true

module Tags
  module Queries
    class Summary
      include Deps[
        "record.queries.journal_entries_by_tag",
        "tasks.queries.tasks_by_tag",
        decisions_by_tag: "decisions.queries.by_tag",
        posts_by_tag: "posts.queries.by_tag",
        projects_by_tag: "projects.queries.by_tag",
        tag_repo: "repos.tag_repo",
      ]

      def call(name)
        tags = tag_repo.named(name)
        return if tags.empty?

        Structs::Summary.new(
          name:, tags:, posts: posts_by_tag.call(name), projects: projects_by_tag.call(name),
          tasks: tasks_by_tag.call(name), journal_entries: journal_entries_by_tag.call(name),
          decisions: decisions_by_tag.call(name),
        )
      end
    end
  end
end
