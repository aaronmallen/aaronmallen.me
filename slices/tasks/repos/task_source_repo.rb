# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceRepo < Blog::DB::Repo
      SYNC_LOCK = 303_304

      include Dry::Monads[:result]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def still_there(provider) = task_sources.still_there(provider).to_a

      def with_sync_lock(&) = task_sources.with_advisory_lock(SYNC_LOCK, busy: Failure(:lock_busy), &)
    end
  end
end
