# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceQueries < Blog::DB::Repo
      include Deps[project_queries: "projects.repos.project_queries"]

      def for_provider(provider) = task_sources.where(provider:).to_a

      def snoozed_tasks = tasks.open.where(id: task_sources.unseen.asleep.task_ids).combine(:source, :tags).to_a

      def synced_task_ids(ids) = task_sources.where(task_id: ids).pluck(:task_id)

      def synced_to_public_board?
        synced = tasks.where(id: task_sources.task_ids).exclude(project_id: nil).pluck(:project_id)

        project_queries.public_board_reached?([*synced, *task_rule_projects.pluck(:project_id)].uniq)
      end

      def task_ids_at(provider, urls)
        task_sources.where(provider:).where(Sequel.function(:lower, :url) => urls.map(&:downcase)).pluck(:task_id)
      end

      def unseen_task_count = unseen.count

      def unseen_tasks = unseen.combine(:source, :tags).newest_first.to_a

      private

      def unseen = tasks.open.where(id: task_sources.unseen.awake.task_ids)
    end
  end
end
