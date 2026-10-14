# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSeriesQueries < Blog::DB::Repo
      def by_id(id) = task_series.by_pk(id).one

      def by_task(task_id) = task_series.where(task_id:).one

      def count = task_series.count

      def listed = task_series.combine(task: :sprint).order(:id).to_a
    end
  end
end
