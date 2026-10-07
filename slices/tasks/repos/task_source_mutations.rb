# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceMutations < DB::Repo
      SYNC_LOCK = 303_304
      SYNC_LOCKS = { "github" => SYNC_LOCK, "linear" => 303_305 }.freeze

      include Dry::Monads[:result]

      root :task_sources

      stamped_commands :create, :update

      def see(task_id, at) = task_sources.see(task_id, at)

      def snooze(task_id, ends_at)
        task_sources.where(task_id:).stamped(:update, result: :many).call(snoozed_until: ends_at).first
      end

      def with_sync_lock(provider, &)
        task_sources.with_advisory_lock(SYNC_LOCKS.fetch(provider), busy: Failure(:lock_busy), &)
      end
    end
  end
end
