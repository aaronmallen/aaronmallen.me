# frozen_string_literal: true

module Tasks
  module Repos
    class WorkSessionRepo < Blog::DB::Repo
      def close(task_id, at) = work_sessions.close(task_id, at)

      def open(task_id, at) = work_sessions.open(task_id, at)
    end
  end
end
