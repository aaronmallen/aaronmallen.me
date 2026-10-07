# frozen_string_literal: true

module Social
  module Repos
    class SocialPostQueries < DB::Repo
      DRAFT = Blog::Types::SocialPostStatus["draft"]
      DRAFTS = Blog::Types::SocialQueue["drafts"]
      POSTED = Blog::Types::SocialPostStatus["posted"]
      POSTED_QUEUE = Blog::Types::SocialQueue["posted"]
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]
      QUEUES = {
        Blog::Types::SocialQueue["queued"] => SCHEDULED,
        POSTED_QUEUE => POSTED,
        DRAFTS => DRAFT,
      }.freeze

      def any_for_post?(post_id) = social_posts.for_post(post_id).exist?

      def by_filter(filter, page)
        case Blog::Types::SocialQueue[filter]
          when DRAFTS then drafts_page(page)
          when POSTED_QUEUE then posted_page(page)
          else queued_page(page)
        end
      end

      def by_id(id) = with_children.by_pk(id).one

      def calendar_between(from:, to:)
        dated = with_children.scheduled_or_posted

        dated.posted_between(Blog::TimeZone.day_start(from), Blog::TimeZone.day_start(to + 1)).oldest_first.to_a
      end

      def claimed?(id) = social_post_deliveries.for_social_post(id).exist?

      def count_by_status = count_statuses(social_posts)

      def count_dated_between(from:, to:)
        counted = count_statuses(social_posts.dated_between(*day_bounds(from, to)))

        QUEUES.transform_values { counted.fetch(it, 0) }
      end

      def dated_between(from:, to:, page:, queue: nil)
        days = social_posts.dated_between(*day_bounds(from, to))
        days = days.with_status(QUEUES.fetch(queue)) if queue

        page_of(days.newest_dated_first, page)
      end

      def drafts = with_children.with_status(DRAFT).newest_first.to_a

      def drafts_page(page) = page_of(social_posts.with_status(DRAFT).newest_first, page)

      def due_scheduled(time) = with_children.due_at(time).oldest_first.to_a

      def editable(id) = with_children.unposted.unclaimed.by_pk(id).one

      def posted_page(page) = page_of(social_posts.with_status(POSTED).newest_first, page)

      def posted_since(time) = with_children.posted_since(time).newest_first.to_a

      def queued = with_children.with_status(SCHEDULED).oldest_first.to_a

      def queued_page(page) = page_of(social_posts.with_status(SCHEDULED).oldest_first, page)

      def syndication_urls(post_id)
        social_post_deliveries.syndicated_for_post(post_id).to_a.to_h { [it.network, it.remote_url] }
      end

      def unsent_page(page) = page_of(social_posts.unposted.in_unsent_order, page)

      private

      def count_statuses(found) = found.counts_by_status.to_a.to_h { [it.status, it.count] }

      def day_bounds(from, to) = [from && Blog::TimeZone.day_start(from), to && Blog::TimeZone.day_start(to + 1)]

      def page_of(listed, page)
        ids = page.fill(listed.paged(page).pluck(:id))

        ids.with(rows: listed.where(id: ids.rows).combine(:parts, :deliveries).to_a)
      end

      def with_children = social_posts.combine(:parts, :deliveries)
    end
  end
end
