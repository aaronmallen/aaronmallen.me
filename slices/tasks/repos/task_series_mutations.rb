# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSeriesMutations < Blog::DB::Repo
      def advance(id, task_id, at) = task_series.by_pk(id).update(task_id:, updated_at: at)

      def clear(task_id) = task_series.where(task_id:).delete

      def current(task_id) = task_series.where(task_id:).lock.one

      def set(task_id, fields, at)
        task_series.set(task_id, fields, at)
        tasks.by_pk(task_id).update(series_id: task_series.where(task_id:).select(:id).dataset)
      end

      def switch(id, paused, at) = task_series.by_pk(id).update(paused:, updated_at: at)
    end
  end
end
