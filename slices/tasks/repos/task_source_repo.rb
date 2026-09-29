# frozen_string_literal: true

module Tasks
  module Repos
    class TaskSourceRepo < Blog::DB::Repo
      SYNC_LOCK = 303_304
      SYNC_LOCKS = { "github" => SYNC_LOCK, "linear" => 303_305 }.freeze

      include Dry::Monads[:result]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def still_there(provider) = task_sources.still_there(provider).to_a

      def with_sync_lock(provider, &)
        task_sources.with_advisory_lock(SYNC_LOCKS.fetch(provider), busy: Failure(:lock_busy), &)
      end
    end
  end
end
