# frozen_string_literal: true

module Social
  module Repos
    class WebmentionQueries < Blog::DB::Repo
      COUNTED_TYPES = [Blog::Types::WebmentionType["like"], Blog::Types::WebmentionType["repost"]].freeze
      LISTED_TYPES = [Blog::Types::WebmentionType["reply"], Blog::Types::WebmentionType["mention"]].freeze
      PENDING = Blog::Types::WebmentionStatus["pending"]
      SETTINGS_ID = 1

      include Deps[normalize_author_url: "operations.normalize_author_url"]

      def by_id(id) = webmentions.by_pk(id).one

      def count_by_post(post_ids) = webmentions.for_posts(post_ids).tally(:post_id)

      def count_by_status = webmentions.tally(:status)

      def count_receipts_from_visitor_since(visitor_hashes, time)
        webmention_receipts.for_visitor(visitor_hashes).received_since(time).count
      end

      def count_receipts_since(time) = webmention_receipts.received_since(time).count

      def count_received_in(from:, to:, post_id: nil)
        days = in_days(from, to)
        days = days.for_post(post_id) if post_id

        days.tally(:status, Blog::Types::WebmentionStatus.values)
      end

      def counted_for(post_id) = approved_for(post_id, COUNTED_TYPES).tally(:type)

      def held = held_webmentions.oldest_first.to_a

      def known_author?(author_url)
        webmentions.by_author_url(normalize_author_url.call(author_url)).known_author?
      end

      def listed_for(post_id) = approved_for(post_id, LISTED_TYPES).oldest_first.to_a

      def page_by_status(status, page) = page.fill(webmentions.with_status(status).newest_first.paged(page).to_a)

      def pending_count = webmentions.with_status(PENDING).count

      def received_between(from:, to:) = in_days(from, to).count

      def received_by_post(from:, to:) = in_days(from, to).tally(:post_id)

      def received_count(post_id) = webmentions.for_post(post_id).count

      def received_in(from:, to:, page:, status: nil, post_id: nil)
        days = in_days(from, to)
        days = days.with_status(status) if status
        days = days.for_post(post_id) if post_id

        page.fill(days.newest_first.paged(page).to_a)
      end

      def settings = stored_settings || created_settings

      def snoozed = webmentions.with_status(PENDING).unseen.asleep.to_a

      def unseen = unseen_pending.newest_first.to_a

      def unseen_count = unseen_pending.count

      private

      def approved_for(post_id, types) = webmentions.approved.for_post(post_id).with_types(types)

      def created_settings
        webmention_settings.claim(SETTINGS_ID)
        stored_settings
      end

      def in_days(from, to)
        first, last = Blog::TimeZone.day_bounds(from, to)
        days = first ? webmentions.received_since(first) : webmentions
        last ? days.received_before(last) : days
      end

      def stored_settings = webmention_settings.by_pk(SETTINGS_ID).one

      def unseen_pending = webmentions.with_status(PENDING).unseen.awake
    end
  end
end
