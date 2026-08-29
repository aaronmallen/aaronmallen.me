# frozen_string_literal: true

module Record
  module Relations
    class SyncStates < Blog::DB::Relation
      schema :sync_states, infer: true

      def for_repos(repos) = where(repo: repos)

      def for_sync(sync) = where(sync:)

      def in_sync_order = order(:sync, Sequel.asc(:repo, nulls: :first))

      def of(kind, sync: nil, repo: nil) = where(kind:, sync:, repo:)

      def of_kind(kind) = where(kind:)

      def per_repo = exclude(repo: nil)

      def record(kind:, sync: nil, repo: nil, **columns)
        command(:record)
          .with(update_statement: excluded([*columns.keys, :updated_at]))
          .call(kind:, sync:, repo:, **columns)
      end

      def with_advisory_lock(key, busy: nil)
        db = dataset.db

        db.synchronize do
          next busy unless db.get(Sequel.function(:pg_try_advisory_lock, key))

          begin
            yield
          ensure
            db.get(Sequel.function(:pg_advisory_unlock, key))
          end
        end
      end
    end
  end
end
