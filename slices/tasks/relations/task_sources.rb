# frozen_string_literal: true

module Tasks
  module Relations
    class TaskSources < Blog::DB::Relation
      GONE = [Blog::Types::TaskSourceState["moved"], Blog::Types::TaskSourceState["deleted"]].freeze

      schema :task_sources, infer: true do
        associations do
          belongs_to :task
        end
      end

      def at(provider, remote_id) = where(provider:, remote_id:)

      def still_there(provider) = where(provider:).exclude(remote_state: GONE)

      def task_ids = unordered.dataset.select(:task_id)

      def with_advisory_lock(key, busy:)
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
