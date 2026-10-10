# frozen_string_literal: true

module Social
  module Relations
    class WebmentionReceipts < Blog::DB::Relation
      schema :webmention_receipts, infer: true

      def claim(post_id:, source_url:, visitor_hashes:, since:, limit:, total_limit:)
        capped_claim(received_since(since), visitor_hashes:, limit:, total_limit:) do
          take(since, post_id:, source_url:, visitor_hash: visitor_hashes.first)
        end
      end

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def received_before(time) = where { received_at < time }

      def received_since(time) = where { received_at >= time }

      private

      def take(since, **receipt)
        stale = Sequel[:webmention_receipts][:received_at] < since

        command(:claim).with(update_where: stale).call(receipt)
      end
    end
  end
end
