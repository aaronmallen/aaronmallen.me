# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCommentRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def delete_local(task_id, id) = local(task_id, id).delete

      def delete_synced(ids) = task_comments.where(id: ids).delete

      def for_task(task_id) = task_comments.for_task(task_id).oldest_first.to_a

      def local?(task_id, id) = local(task_id, id).exist?

      def synced(task_id, provider, remote_ids)
        task_comments.where(provider:).where(Sequel.|({ task_id: }, { remote_id: remote_ids })).to_a
      end

      private

      def local(task_id, id) = task_comments.local.for_task(task_id).by_pk(id)
    end
  end
end
