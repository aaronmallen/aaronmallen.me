# frozen_string_literal: true

module Links
  class Records
    TITLE_LIMIT = 120
    WORK = Blog::Types::ProjectFilter["work"]

    include Deps[
      "routes",
      task: "tasks.queries.linkable_tasks",
      post: "posts.queries.linkable_posts",
      social_post: "social.queries.linkable_social_posts",
      journal_entry: "record.queries.linkable_journal_entries",
      commit: "record.queries.linkable_commits",
      project: "projects.queries.linkable_projects",
      work_entry: "projects.queries.linkable_work_entries",
      decision: "decisions.queries.linkable_decisions",
    ]

    def matching(kind, text, limit:) = linked(kind, query(kind).matching(text, limit:))

    def named(kind, ids) = linked(kind, query(kind).named(ids))

    private

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
      else listed_url(kind, row)
      end
    end
  end
end
