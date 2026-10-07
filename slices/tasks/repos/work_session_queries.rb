# frozen_string_literal: true

module Tasks
  module Repos
    class WorkSessionQueries < DB::Repo
      def find(task_id, id) = work_sessions.for_task(task_id).by_pk(id).one
    end
  end
end
