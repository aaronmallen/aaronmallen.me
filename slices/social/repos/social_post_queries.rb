# frozen_string_literal: true

module Social
  module Repos
    class SocialPostQueries < Blog::DB::Repo
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]
      QUEUES = {
        Blog::Types::SocialQueue["queued"] => SCHEDULED,
        Blog::Types::SocialQueue["posted"] => Blog::Types::SocialPostStatus["posted"],
        Blog::Types::SocialQueue["drafts"] => Blog::Types::SocialPostStatus["draft"],
      }.freeze

      def any_for_post?(post_id) = social_posts.for_post(post_id).exist?

      def by_filter(filter, page)
        status = QUEUES.fetch(Blog::Types::SocialQueue[filter])
        listed = social_posts.with_status(status)

        page_of(status == SCHEDULED ? listed.oldest_first : listed.newest_first, page)
      end

      def by_id(id) = with_children.by_pk(id).one

      def calendar_between(from:, to:)
        dated = with_children.scheduled_or_posted

        dated.posted_between(*Blog::TimeZone.day_bounds(from, to)).oldest_first.to_a
      end

      def claimed?(id) = social_post_deliveries.for_social_post(id).exist?

      def count_by_status = social_posts.tally(:status)

      def count_dated_between(from:, to:)
        counted = social_posts.dated_between(*Blog::TimeZone.day_bounds(from, to)).tally(:status)

        QUEUES.transform_values { counted.fetch(it, 0) }
      end

      def dated_between(from:, to:, page:, queue: nil)
        days = social_posts.dated_between(*Blog::TimeZone.day_bounds(from, to))
        days = days.with_status(QUEUES.fetch(queue)) if queue

        page_of(days.newest_dated_first, page)
      end

      def due_scheduled(time) = with_children.due_at(time).oldest_first.to_a

      def editable(id) = with_children.unposted.unclaimed.by_pk(id).one

      def failed_statuses = social_posts.with_failed_delivery.pluck(:status)

      def next_queued_at = social_posts.with_status(SCHEDULED).oldest_first.limit(1).pluck(:posted_at).first

      def part_photo_keys(social_post_id)
        part_ids = social_post_parts.for_social_post(social_post_id).pluck(:id)
        held = social_post_photos.for_parts(part_ids).in_order.to_a.group_by(&:social_post_part_id)

        part_ids.to_h { [it, held.fetch(it, Blog::Constants::EMPTY_ARRAY).map(&:photo_key)] }
      end

      def photos_by_post(social_post_ids)
        parts = social_post_parts.where(social_post_id: social_post_ids).in_order.combine(:photos)

        parts.to_a.group_by(&:social_post_id).transform_values { it.flat_map(&:photos) }
      end

      def posted_since(time) = with_children.posted_since(time).newest_first.to_a

      def scheduled_mentioning(key)
        social_posts.with_status(SCHEDULED).matching("@{#{key}}").oldest_first.limit(1).pluck(:id).first
      end

      def syndication_urls(post_id)
        social_post_deliveries.syndicated_for_post(post_id).to_a.to_h { [it.network, it.remote_url] }
      end

      def unsent_page(page) = page_of(social_posts.unposted.in_unsent_order, page)

      private

      def page_of(listed, page)
        ids = page.fill(listed.paged(page).pluck(:id))

        ids.with(rows: listed.where(id: ids.rows).combine(:deliveries, parts: :photos).to_a)
      end

      def with_children = social_posts.combine(:deliveries, parts: :photos)
    end
  end
end
