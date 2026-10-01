# frozen_string_literal: true

module Contact
  module Relations
    class Messages < Blog::DB::Relation
      TABLE_KEY = Sequel.function(:hashtext, "messages")

      schema :messages, infer: true

      def claim(visitor_hash:, limit:, total_limit:, since:, **attrs)
        transaction do
          lock_table_until_commit
          fresh = received_since(since)
          next unless fresh.for_visitor(visitor_hash).count < limit && fresh.count < total_limit

          stamped(:create, :received_at).call(**attrs, visitor_hash:)
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def marked_spam_before(time) = where { marked_spam_at < time }

      def newest_first = order(self[:received_at].desc, self[:id].desc)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      def with_status(status) = where(status:)

      private

      def lock_table_until_commit = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY))
    end
  end
end
