# frozen_string_literal: true

module Tasks
  module Repos
    class TaskLinkQueries < Blog::DB::Repo
      def open_ids(ids) = tasks.where(id: ids).open.pluck(:id)

      def synced?(task_id) = touching(task_id).where(synced: true).exist?

      def touching_all(task_ids) = touching(task_ids).to_a

      private

      def touching(task_ids) = task_links.where(Sequel.|({ from_task_id: task_ids }, { to_task_id: task_ids }))
    end
  end
end
