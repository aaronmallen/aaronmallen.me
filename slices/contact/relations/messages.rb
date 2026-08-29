# frozen_string_literal: true

module Contact
  module Relations
    class Messages < Blog::DB::Relation
      TABLE_KEY = Sequel.function(:hashtext, "messages")

      schema :messages, infer: true

      def claim(visitor_hash:, limit:, since:, **attrs)
        transaction do
          lock_until_commit(visitor_hash)
          next unless for_visitor(visitor_hash).received_since(since).count < limit

          stamped(:create, :received_at).call(**attrs, visitor_hash:)
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def with_status(status) = where(status:)

      private

      def lock_until_commit(visitor_hash)
        dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY, Sequel.function(:hashtext, visitor_hash)))
      end
    end
  end
end
