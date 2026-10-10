# frozen_string_literal: true

module Posts
  module Relations
    class PostLinkChecks < Blog::DB::Relation
      KEY = %i[post_id url].freeze

      schema :post_link_checks, infer: true

      def outside(post_ids) = exclude(post_id: post_ids)

      def record(post_id:, url:, reason:, at:)
        failures = reason ? 1 : 0
        update = excluded(%i[reason checked_at]).merge(failures: reason ? Sequel[:post_link_checks][:failures] + 1 : 0)

        upsert({ post_id:, url:, reason:, failures:, checked_at: at }, target: KEY, update:)
      end

      def unlinked(post_id, urls) = where(post_id:).exclude(url: urls)
    end
  end
end
