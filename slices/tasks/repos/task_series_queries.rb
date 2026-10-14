# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSeriesQueries < Blog::DB::Repo
      def by_id(id) = task_series.by_pk(id).one

      def by_task(task_id) = task_series.where(task_id:).one

      def count = task_series.count

      def listed = with_task.order(:id).to_a

      def shown(id) = with_task.by_pk(id).one

      private

      def with_task = task_series.combine(task: :sprint)
    end
  end
end
