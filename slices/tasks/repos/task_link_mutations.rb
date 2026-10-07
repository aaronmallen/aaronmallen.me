# frozen_string_literal: true

module Tasks
  module Repos
    class TaskLinkMutations < DB::Repo
      root :task_links

      def add_synced(from_task_id:, to_task_id:, type:)
        task_links.command(:create).call(from_task_id:, to_task_id:, type:, synced: true)
      end

      def delete(ids) = task_links.where(id: ids).delete

      def update(id, **) = task_links.by_pk(id).command(:update).call(**)
    end
  end
end
