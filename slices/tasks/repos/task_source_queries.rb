# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceQueries < DB::Repo
      def for_provider(provider) = task_sources.where(provider:).to_a

      def snoozed_tasks = tasks.open.where(id: task_sources.unseen.asleep.task_ids).combine(:source, :tags).to_a

      def synced_task_ids(ids) = task_sources.where(task_id: ids).pluck(:task_id)

      def task_ids_at(provider, urls) = task_sources.where(provider:, url: urls).pluck(:task_id)

      def unseen_task_count = unseen.count

      def unseen_tasks = unseen.combine(:source, :tags).newest_first.to_a

      private

      def unseen = tasks.open.where(id: task_sources.unseen.awake.task_ids)
    end
  end
end
