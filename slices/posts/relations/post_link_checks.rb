# frozen_string_literal: true

module Posts
  module Relations
    class PostLinkChecks < Blog::DB::Relation
      KEY = %i[post_id url].freeze

      schema :post_link_checks, infer: true

      def failing = exclude(reason: nil)

      def outside(post_ids) = exclude(post_id: post_ids)

      def record(post_id:, url:, reason:, at:)
        failures = reason ? 1 : 0
        first_failed_at = at if reason
        update = excluded(%i[reason checked_at]).merge(
          failures: reason ? Sequel[:post_link_checks][:failures] + 1 : 0,
          first_failed_at: reason ? Sequel.function(:coalesce, Sequel[:post_link_checks][:first_failed_at], at) : nil,
        )

        upsert({ post_id:, url:, reason:, failures:, first_failed_at:, checked_at: at }, target: KEY, update:)
      end

      def unlinked(post_id, urls) = where(post_id:).exclude(url: urls)
    end
  end
end
