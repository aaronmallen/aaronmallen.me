# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSeriesQueries < Blog::DB::Repo
      def by_id(id) = task_series.by_pk(id).one

      def by_task(task_id) = task_series.where(task_id:).one
    end
  end
end
