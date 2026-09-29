# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCommentRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def delete_local(task_id, id) = local(task_id, id).delete

      def for_task(task_id) = task_comments.for_task(task_id).oldest_first.to_a

      def local?(task_id, id) = local(task_id, id).exist?

      private

      def local(task_id, id) = task_comments.local.for_task(task_id).by_pk(id)
    end
  end
end
