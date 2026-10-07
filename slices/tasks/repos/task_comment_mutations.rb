# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCommentMutations < DB::Repo
      root :task_comments

      stamped_commands :create, :update

      def delete_local(task_id, id) = task_comments.local.for_task(task_id).by_pk(id).delete

      def delete_synced(ids) = task_comments.where(id: ids).delete
    end
  end
end
