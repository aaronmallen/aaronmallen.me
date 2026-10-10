# frozen_string_literal: true

module Links
  module Repos
    class RecordLinkQueries < Blog::DB::Repo
      FOUND_LIMIT = 5
      RELATIONS = {
        "commit" => :commits,
        "decision" => :decisions,
        "journal_entry" => :journal_entries,
        "post" => :posts,
        "project" => :projects,
        "pull_request" => :pull_requests,
        "social_post" => :social_posts,
        "task" => :tasks,
        "work_entry" => :work_entries,
      }.freeze
      TITLE_LIMIT = 120
      WORK = Blog::Types::ProjectFilter["work"]

      include Deps[
        "routes",
        post: "posts.repos.post_queries",
        social_post: "social.repos.social_post_queries",
        journal_entry: "record.repos.journal_entry_queries",
        commit: "record.repos.commit_queries",
        project: "projects.repos.project_queries",
        work_entry: "projects.repos.work_entry_queries",
        decision: "decisions.repos.decision_queries",
        pull_request: "record.repos.pull_request_queries",
        task: "tasks.repos.task_queries",
      ]

      def counts(kind, ids)
        record_links.touching(kind, ids).to_a.flat_map do |link|
          [(link.left_id if link.left_kind == kind), (link.right_id if link.right_kind == kind)].compact
        end.tally
      end

      def find(text, limit: FOUND_LIMIT)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_HASH if query.empty?

        Blog::Types::RecordKind.values.to_h { [it, linked(it, rows(it, text: query, limit:))] }.reject { _2.empty? }
      end

      def for_record(kind, id)
        id = Blog::Types::IdParam[id]
        return Blog::Constants::EMPTY_HASH unless id

        ids = partners(kind, id).group_by(&:first).transform_values { it.map(&:last) }

        Blog::Types::RecordKind.values.filter_map { [it, named(it, ids[it])] if ids.key?(it) }.to_h
      end

      def named(kind, ids) = linked(kind, rows(kind, ids:))

      def partners(kind, id)
        record_links.touching(kind, id).to_a.map do |link|
          left = [link.left_kind, link.left_id]

          left == [kind, id] ? [link.right_kind, link.right_id] : left
        end
      end

      private

      def linked(kind, rows)
        rows.map do |row|
          title = Blog::Helpers::Truncation.fit(row.title, limit: TITLE_LIMIT)

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

      def rows(kind, **) = public_send(kind).linkable(RELATIONS.fetch(kind), **)

      def url(kind, row)
        id = row.id

        case kind
          when "task" then routes.path(:admin_task, id:)
          when "post" then routes.path(:admin_edit_post, id:)
          when "commit" then routes.path(:admin_commit, id:)
          when "project" then routes.path(:admin_edit_project, id:)
          when "decision" then routes.path(:admin_decision, id:)
          when "pull_request" then routes.path(:admin_pull_request, id:)
          else listed_url(kind, row)
        end
      end
    end
  end
end
