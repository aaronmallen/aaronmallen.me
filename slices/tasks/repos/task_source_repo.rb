# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceRepo < DB::Repo
      SYNC_LOCK = 303_304
      SYNC_LOCKS = { "github" => SYNC_LOCK, "linear" => 303_305 }.freeze

      include Dry::Monads[:result]

      stamped_commands :create, :update

      def for_provider(provider) = task_sources.where(provider:).to_a

      def see(task_id, at) = task_sources.see(task_id, at)

      def snooze(task_id, ends_at)
        task_sources.where(task_id:).stamped(:update, result: :many).call(snoozed_until: ends_at).first
      end

      def snoozed_tasks = tasks.open.where(id: task_sources.unseen.asleep.task_ids).combine(:source, :tags).to_a

      def synced_task_ids(ids) = task_sources.where(task_id: ids).pluck(:task_id)

      def task_ids_at(provider, urls) = task_sources.where(provider:, url: urls).pluck(:task_id)

      def unseen_task_count = unseen.count

      def unseen_tasks = unseen.combine(:source, :tags).newest_first.to_a

      def with_sync_lock(provider, &)
        task_sources.with_advisory_lock(SYNC_LOCKS.fetch(provider), busy: Failure(:lock_busy), &)
      end

      private

      def unseen = tasks.open.where(id: task_sources.unseen.awake.task_ids)
    end
  end
end
