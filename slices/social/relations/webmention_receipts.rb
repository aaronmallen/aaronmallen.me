# frozen_string_literal: true

module Social
  module Relations
    class WebmentionReceipts < Blog::DB::Relation
      TABLE_KEY = Sequel.function(:hashtext, "webmention_receipts")

      schema :webmention_receipts, infer: true

      def claim(post_id:, source_url:, visitor_hash:, since:, limit:, total_limit:)
        dataset.db.transaction do
          lock_table_until_commit
          fresh = received_since(since)
          next unless fresh.for_visitor(visitor_hash).count < limit && fresh.count < total_limit

          take(since, post_id:, source_url:, visitor_hash:)
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      private

      def lock_table_until_commit = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY))

      def take(since, **receipt)
        stale = Sequel[:webmention_receipts][:received_at] < since

        command(:claim).with(update_where: stale).call(receipt)
      end
    end
  end
end
