# frozen_string_literal: true

module Tasks
  module Operations
    class SyncComments
      EMPTY_ARRAY = Blog::Constants::EMPTY_ARRAY
      FIELDS = %i[author body url].freeze
      VISIBLE = /[[:^space:]]/

      include Deps[
        task_comment_mutations: "repos.task_comment_mutations",
        task_comment_queries: "repos.task_comment_queries",
      ]

      def call(source, task, issue, run)
        held = run.held
        made, edited, gone = changes(source, task, issue, held)

        made.each { held[it[:remote_id]] = create(source, it) }
        edited.each { |row, fields| held[row.remote_id] = task_comment_mutations.update(row.id, **fields) }
        drop(gone, held)
      end

      def hold(run, task_ids, issues)
        return if task_ids.empty?

        remote_ids = issues.select { it.key?(:comments) }.flat_map { heard(it).keys }
        task_comment_queries.synced(task_ids, run.provider, remote_ids).each { run.held[it.remote_id] = it }
      end

      def quiet?(source, task, issue, run) = changes(source, task, issue, run.held).all?(&:empty?)

      private

      def changes(source, task, issue, held)
        return [EMPTY_ARRAY] * 3 unless listening?(task, issue)

        fresh = heard(issue)
        mine = mine(source, fresh, held)
        made, kept = fresh.values.partition { !mine.key?(it[:remote_id]) }

        [made, kept.filter_map { edit(mine[it[:remote_id]], source, it) }, gone(issue, fresh, mine)]
      end

      def create(source, comment)
        task_comment_mutations.create(**comment, task_id: source.task_id, provider: source.provider)
      end

      def drop(gone, held)
        return if gone.empty?

        task_comment_mutations.delete_synced(gone.map(&:id))
        gone.each { held.delete(it.remote_id) }
      end

      def edit(row, source, comment)
        changes = { **comment.slice(*FIELDS), task_id: source.task_id }
        [row, changes] unless changes == row.to_h.slice(*changes.keys)
      end

      def gone(issue, fresh, mine) = issue[:comments_cut_short] ? EMPTY_ARRAY : mine.except(*fresh.keys).values

      def heard(issue) = issue.fetch(:comments).filter_map { said(it) }.to_h { [it[:remote_id], it] }

      def listening?(task, issue) = issue.key?(:comments) && !task.closed?

      def mine(source, fresh, held) = held.select { |id, row| row.task_id == source.task_id || fresh.key?(id) }

      def said(comment)
        body = comment[:body]&.delete("\0")
        return unless body&.match?(VISIBLE)

        { author: comment[:author], body:, created_at: comment[:created_at], remote_id: comment.fetch(:id),
          url: comment.fetch(:url) }
      end
    end
  end
end
