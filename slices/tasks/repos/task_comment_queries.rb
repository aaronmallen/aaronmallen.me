# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCommentQueries < Blog::DB::Repo
      def editable_comment?(task_id, id) = task_comments.local.for_task(task_id).by_pk(id).exist?

      def edited_ids(task_id) = task_comments.local.for_task(task_id).where { updated_at > created_at }.pluck(:id)

      def for_task(task_id) = task_comments.for_task(task_id).oldest_first.to_a

      def ids_for_task(task_id) = task_comments.for_task(task_id).pluck(:id)

      def synced(task_id, provider, remote_ids)
        task_comments.where(provider:).where(Sequel.|({ task_id: }, { remote_id: remote_ids })).to_a
      end
    end
  end
end
