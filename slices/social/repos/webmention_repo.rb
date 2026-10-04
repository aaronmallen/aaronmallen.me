# frozen_string_literal: true

module Social
  module Repos
    class WebmentionRepo < Blog::DB::Repo
      include Dry::Monads[:result]

      APPROVED = Blog::Types::WebmentionStatus["approved"]
      BARE_HOST = %r{\A(https?://[^/?#]+)\z}
      COUNTED_TYPES = [Blog::Types::WebmentionType["like"], Blog::Types::WebmentionType["repost"]].freeze
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
      LISTED_TYPES = [Blog::Types::WebmentionType["reply"], Blog::Types::WebmentionType["mention"]].freeze
      PENDING = Blog::Types::WebmentionStatus["pending"]
      RESENT_FIELDS = %i[author_name author_url excerpt type].freeze
      SETTINGS_ID = 1
      SPAM = Blog::Types::WebmentionStatus["spam"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def approve(id) = update(id, status: APPROVED, spam_reason: nil)

      def by_status(status) = webmentions.with_status(status).newest_first.to_a

      def claim_receipt(post_id:, source_url:, visitor_hash:, since:, limit:, total_limit:)
        receipt = webmention_receipts.claim(post_id:, source_url:, visitor_hash:, since:, limit:, total_limit:)&.first

        receipt ? Success(receipt) : Failure(:throttled)
      end

      def count_by_post(post_ids) = tallied(webmentions.for_posts(post_ids).counts_by(:post_id), :post_id)

      def count_by_status = tallied(webmentions.counts_by(:status), :status)

      def count_receipts_from_visitor_since(visitor_hash, time)
        webmention_receipts.for_visitor(visitor_hash).received_since(time).count
      end

      def count_receipts_since(time) = webmention_receipts.received_since(time).count

      def counted_for(post_id) = tallied(approved_for(post_id, COUNTED_TYPES).counts_by(:type), :type)

      def delete_by_source(post_id, source_url) = webmentions.for_post(post_id).from_source(source_url).delete

      def delete_receipts_before(time) = webmention_receipts.received_before(time).delete

      def held = held_webmentions.oldest_first.to_a

      def hold(**) = held_webmentions.hold(**)

      def ignore(id) = update(id, status: IGNORED, spam_reason: nil)

      def known_author?(author_url) = webmentions.by_author_url(normalized_author_url(author_url)).known_author?

      def listed_for(post_id) = approved_for(post_id, LISTED_TYPES).oldest_first.to_a

      def mark_spam(id, reason = nil) = update(id, status: SPAM, spam_reason: reason)

      def normalized_author_url(url) = Blog::Types::Normalized::Url.call(url) { url }.sub(BARE_HOST, '\\1/')

      def page_by_status(status, page) = page.fill(webmentions.with_status(status).newest_first.paged(page).to_a)

      def pending(limit: nil)
        found = webmentions.with_status(PENDING).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def pending_count = webmentions.with_status(PENDING).count

      def received_between(from:, to:) = in_days(from, to).count

      def received_by_post(from:, to:) = tallied(in_days(from, to).counts_by(:post_id), :post_id)

      def received_count(post_id) = webmentions.for_post(post_id).count

      def received_in(from:, to:, page:, status: nil)
        days = in_days(from, to)

        page.fill((status ? days.with_status(status) : days).newest_first.paged(page).to_a)
      end

      def release(id) = held_webmentions.by_pk(id).delete

      def settings = stored_settings || created_settings

      def store(**attrs)
        written = attrs.merge(author_url: normalized_author_url(attrs[:author_url]))

        webmentions.store(resent: written.slice(*RESENT_FIELDS).keys, **written)
      end

      def update_settings(**attrs)
        transaction do
          settings
          webmention_settings.by_pk(SETTINGS_ID).stamped(:update).call(**attrs)
        end

        stored_settings
      end

      private

      def approved_for(post_id, types) = webmentions.approved.for_post(post_id).with_types(types)

      def created_settings
        webmention_settings.claim(SETTINGS_ID)
        stored_settings
      end

      def in_days(from, to)
        webmentions.received_since(Blog::TimeZone.day_start(from)).received_before(Blog::TimeZone.day_start(to + 1))
      end

      def stored_settings = webmention_settings.by_pk(SETTINGS_ID).one

      def tallied(counts, key) = counts.to_a.to_h { [it[key], it.count] }
    end
  end
end
