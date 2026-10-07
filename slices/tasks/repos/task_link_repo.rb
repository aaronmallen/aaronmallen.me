# frozen_string_literal: true

module Tasks
  module Repos
    class TaskLinkRepo < DB::Repo
      def add_synced(from_task_id:, to_task_id:, type:)
        task_links.command(:create).call(from_task_id:, to_task_id:, type:, synced: true)
      end

      def delete(ids) = task_links.where(id: ids).delete

      def open_ids(ids) = tasks.where(id: ids).open.pluck(:id)

      def synced?(task_id) = touching(task_id).where(synced: true).exist?

      def touching_all(task_ids) = touching(task_ids).to_a

      def update(id, **) = task_links.by_pk(id).command(:update).call(**)

      private

      def touching(task_ids) = task_links.where(Sequel.|({ from_task_id: task_ids }, { to_task_id: task_ids }))
    end
  end
end
