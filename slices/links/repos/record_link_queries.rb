# frozen_string_literal: true

module Links
  module Repos
    class RecordLinkQueries < Blog::DB::Repo
      FOUND_LIMIT = 5
      MEMORY_FILE = Blog::Types::RecordKind["memory_file"]
      RELATIONS = {
        "artifact" => :artifacts,
        "commit" => :commits,
        "decision" => :decisions,
        "journal_entry" => :journal_entries,
        "mail_thread" => :mail_threads,
        "memory_file" => :memory_files,
        "note" => :notes,
        "note_folder" => :note_folders,
        "post" => :posts,
        "project" => :projects,
        "pull_request" => :pull_requests,
        "social_post" => :social_posts,
        "task" => :tasks,
        "work_entry" => :work_entries,
      }.freeze
      TITLE_LIMIT = 120

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
        task: "tasks.repos.task_label_queries",
        mail_thread: "mail.repos.thread_queries",
        memory_file: "agents.repos.memory_file_queries",
        artifact: "agents.repos.artifact_queries",
        note: "notes.repos.note_queries",
        note_folder: "notes.repos.note_queries",
      ]

      def counts(kind, ids)
        touching(kind, ids).flat_map do |link|
          [(link.left_id if link.left_kind == kind), (link.right_id if link.right_kind == kind)].compact
        end.tally
      end

      def find(text, limit: FOUND_LIMIT)
        query = Blog::Types::TrimmedText[text]
        return Blog::Constants::EMPTY_HASH if query.empty?

        found = picked(query, limit).group_by { it.delete(:kind) }

        Blog::Types::RecordKind.values.filter_map { [it, linked(it, found[it])] if found.key?(it) }.to_h
      end

      def for_record(kind, id)
        id = Blog::Types::IdParam[id]
        return Blog::Constants::EMPTY_HASH unless id

        links = partnered(kind, id)
        scoped = links.filter_map { |pair, fixed| pair if fixed }
        ids = grouped(links.map(&:first).uniq)

        Blog::Types::RecordKind.values.filter_map { [it, named(it, ids[it], scoped:)] if ids.key?(it) }.to_h
      end

      def named(kind, ids, scoped: Blog::Constants::EMPTY_ARRAY) = linked(kind, rows(kind, ids:), scoped)

      def partner_ids(kind, ids, other_kind)
        touching(kind, ids).filter_map do |link|
          sides = [[link.left_kind, link.left_id], [link.right_kind, link.right_id]]
          own, partner = sides.first.first == kind ? sides : sides.reverse

          [own.last, partner.last] if partner.first == other_kind
        end.to_h
      end

      private

      def branch(kind, text, limit)
        found = public_send(kind).linkable_matching(RELATIONS.fetch(kind), text, limit)
        place = Sequel.function(:row_number).over(order: found.opts[:order])

        found.from_self.select_append(Sequel.as(kind, :kind), place.as(:place))
      end

      def grouped(pairs) = pairs.group_by(&:first).transform_values { it.map(&:last) }

      def linked(kind, rows, scoped = Blog::Constants::EMPTY_ARRAY)
        rows.map do |row|
          row => { id:, title:, day: }
          url = Blog::Helpers::RecordKinds.path(routes, kind, id:, day:)
          title = Blog::Helpers::Truncation.fit(title, limit: TITLE_LIMIT)

          Structs::Link.new(kind:, id:, title:, day:, url:, scoped: scoped.include?([kind, id]))
        end
      end

      def partner(link, kind, id)
        left = [link.left_kind, link.left_id]

        left == [kind, id] ? [link.right_kind, link.right_id] : left
      end

      def partnered(kind, id) = record_links.touching(kind, id).to_a.map { [partner(it, kind, id), scoped?(it)] }

      def picked(text, limit)
        branches = Blog::Types::RecordKind.values.map { branch(it, text, limit) }

        branches.reduce { |all, more| all.union(more, all: true) }.order(:place).to_a
      end

      def rows(kind, **) = public_send(kind).linkable(RELATIONS.fetch(kind), **)

      def scoped?(link) = link.id.nil? && link.right_kind == MEMORY_FILE

      def touching(kind, ids)
        record_links.touching(kind, ids).to_a.uniq { [it.left_kind, it.left_id, it.right_kind, it.right_id] }
      end
    end
  end
end
