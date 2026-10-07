# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCommentRepo < DB::Repo
      stamped_commands :create, :update

      def delete_local(task_id, id) = local(task_id, id).delete

      def delete_synced(ids) = task_comments.where(id: ids).delete

      def for_task(task_id) = task_comments.for_task(task_id).oldest_first.to_a

      def ids_for_task(task_id) = task_comments.for_task(task_id).pluck(:id)

      def local?(task_id, id) = local(task_id, id).exist?

      def synced(task_id, provider, remote_ids)
        task_comments.where(provider:).where(Sequel.|({ task_id: }, { remote_id: remote_ids })).to_a
      end

      private

      def local(task_id, id) = task_comments.local.for_task(task_id).by_pk(id)
    end
  end
end
