# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSeriesMutations < Blog::DB::Repo
      def clear(task_id) = task_series.where(task_id:).delete

      def set(task_id, fields, at) = task_series.set(task_id, fields, at)
    end
  end
end
