# frozen_string_literal: true

module Links
  module Queries
    class LinkableRecords
      RELATIONS = {
        "commit" => :commits,
        "decision" => :decisions,
        "journal_entry" => :journal_entries,
        "project" => :projects,
        "work_entry" => :work_entries,
      }.freeze
      TITLE_LIMIT = 120
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps[
        "routes",
        task: "tasks.queries.linkable_tasks",
        post: "posts.queries.linkable_posts",
        social_post: "social.queries.linkable_social_posts",
        journal_entry: "record.repos.journal_entry_queries",
        commit: "record.repos.commit_queries",
        project: "projects.repos.project_queries",
        work_entry: "projects.repos.work_entry_queries",
        decision: "decisions.repos.decision_queries",
      ]

      def matching(kind, text, limit:)
        rows = RELATIONS.key?(kind) ? linkable(kind, text:, limit:) : query(kind).matching(text, limit:)

        linked(kind, rows)
      end

      def named(kind, ids) = linked(kind, RELATIONS.key?(kind) ? linkable(kind, ids:) : query(kind).named(ids))

      private

      def linkable(kind, **) = query(kind).linkable(RELATIONS.fetch(kind), **)

      def linked(kind, rows)
        rows.map do |row|
          title = Blog::Truncation.fit(row.title, limit: TITLE_LIMIT)

          Structs::Link.new(kind:, id: row.id, title:, day: row.day, url: url(kind, row))
        end
      end

      def listed_url(kind, row)
        case kind
        when "social_post" then routes.path(:admin_social, edit: row.id)
        when "journal_entry" then "#{routes.path(:admin_journal, to: row.day)}#day-#{row.day.iso8601}"
        when "work_entry" then routes.path(:admin_projects, filter: WORK)
        end
      end

      def query(kind) = public_send(kind)

      def url(kind, row)
        id = row.id

        case kind
        when "task" then routes.path(:admin_task, id:)
        when "post" then routes.path(:admin_edit_post, id:)
        when "commit" then routes.path(:admin_commit, id:)
        when "project" then routes.path(:admin_edit_project, id:)
        when "decision" then routes.path(:admin_decision, id:)
        else listed_url(kind, row)
        end
      end
    end
  end
end
