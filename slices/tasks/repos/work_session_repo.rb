# frozen_string_literal: true

module Tasks
  module Repos
    class WorkSessionRepo < Blog::DB::Repo
      stamped_commands :update

      def close(task_id, at) = work_sessions.close(task_id, at)

      def delete(id) = work_sessions.by_pk(id).delete

      def find(task_id, id) = work_sessions.for_task(task_id).by_pk(id).one

      def lock_task(task_id) = tasks.by_pk(task_id).lock.one

      def open(task_id, at) = work_sessions.open(task_id, at)

      def restart(task_id, at)
        work_sessions.split([task_id], at) if work_sessions.running.for_task(task_id).exist?
      end

      def shift_total(task_id, seconds)
        tasks.by_pk(task_id).update(worked_seconds: Sequel.function(:greatest, 0, Sequel[:worked_seconds] + seconds))
      end
    end
  end
end
