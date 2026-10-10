# frozen_string_literal: true

module Tasks
  module Operations
    class SyncComments < Operation
      FIELDS = %i[author body url].freeze
      VISIBLE = /[[:^space:]]/

      include Deps[
        task_comment_mutations: "repos.task_comment_mutations",
        task_comment_queries: "repos.task_comment_queries",
      ]

      def call(source, task, issue)
        return unless listening?(task, issue)

        fresh = heard(issue)
        held = held(source, fresh.keys)

        fresh.each_value { keep(held[it[:remote_id]], source, it) }
        drop(held.except(*fresh.keys).values) unless issue[:comments_cut_short]
      end

      private

      def drop(gone) = gone.empty? || task_comment_mutations.delete_synced(gone.map(&:id))

      def heard(issue) = issue.fetch(:comments).filter_map { said(it) }.to_h { [it[:remote_id], it] }

      def held(source, remote_ids)
        task_comment_queries.synced(source.task_id, source.provider, remote_ids).to_h { [it.remote_id, it] }
      end

      def keep(held, source, comment)
        return task_comment_mutations.create(**comment, task_id: source.task_id, provider: source.provider) unless held

        changes = { **comment.slice(*FIELDS), task_id: source.task_id }
        task_comment_mutations.update(held.id, **changes) unless changes == held.to_h.slice(*changes.keys)
      end

      def listening?(task, issue) = issue.key?(:comments) && !task.closed?

      def said(comment)
        body = comment[:body]&.delete("\0")
        return unless body&.match?(VISIBLE)

        { author: comment[:author], body:, created_at: comment[:created_at], remote_id: comment.fetch(:id),
          url: comment.fetch(:url) }
      end
    end
  end
end
