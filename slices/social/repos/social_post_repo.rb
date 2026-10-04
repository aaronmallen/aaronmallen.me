# frozen_string_literal: true

module Social
  module Repos
    class SocialPostRepo < Blog::DB::Repo
      DRAFT = Blog::Types::SocialPostStatus["draft"]
      POSTED = Blog::Types::SocialPostStatus["posted"]
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def any_for_post?(post_id) = social_posts.for_post(post_id).exist?

      def by_id(id) = with_children.by_pk(id).one

      def calendar_between(from:, to:)
        dated = with_children.scheduled_or_posted

        dated.posted_between(Blog::TimeZone.day_start(from), Blog::TimeZone.day_start(to + 1)).oldest_first.to_a
      end

      def claim_delivery(social_post_id, network, due_by:, stale_before:)
        transaction do
          next unless lock_due(social_post_id, due_by)

          social_post_deliveries.claim(social_post_id:, network:, stale_before:)
        end
      end

      def claimed?(id) = social_post_deliveries.for_social_post(id).exist?

      def count_by_status = social_posts.counts_by_status.to_a.to_h { [it.status, it.count] }

      def create_with_parts(parts:, **attrs)
        social_post = transaction do
          created = create(**attrs)
          insert_parts(created.id, parts)
          created
        end

        by_id(social_post.id)
      end

      def dated_between(from:, to:, page:)
        days = social_posts.dated_between(Blog::TimeZone.day_start(from), Blog::TimeZone.day_start(to + 1))

        page_of(days.newest_dated_first, page)
      end

      def delete_unposted(id)
        transaction { lock_unclaimed(id) ? unclaimed(id).delete : 0 }
      end

      def drafts = with_children.with_status(DRAFT).newest_first.to_a

      def drafts_page(page) = page_of(social_posts.with_status(DRAFT).newest_first, page)

      def due_scheduled(time) = with_children.due_at(time).oldest_first.to_a

      def editable(id) = with_children.unposted.unclaimed.by_pk(id).one

      def locked_editable(id) = unposted(id).lock.one && editable(id)

      def mark_posted(id, at: Time.now) = social_posts.mark_posted(id, at:)

      def posted_page(page) = page_of(social_posts.with_status(POSTED).newest_first, page)

      def posted_since(time) = with_children.posted_since(time).newest_first.to_a

      def queued = with_children.with_status(SCHEDULED).oldest_first.to_a

      def queued_page(page) = page_of(social_posts.with_status(SCHEDULED).oldest_first, page)

      def record_delivery(social_post_id, network, **attrs)
        social_post_deliveries.record(social_post_id:, network:, **attrs)
      end

      def replace_parts(id, parts)
        transaction do
          next unless lock_unclaimed(id)

          social_post_parts.for_social_post(id).delete
          insert_parts(id, parts)
          by_id(id)
        end
      end

      def syndication_urls(post_id)
        social_post_deliveries.syndicated_for_post(post_id).to_a.to_h { [it.network, it.remote_url] }
      end

      def unsent_page(page) = page_of(social_posts.unposted.in_unsent_order, page)

      def update_with_parts(id, parts:, **attrs)
        transaction do
          next unless lock_unclaimed(id)

          update(id, **attrs)
          social_post_parts.for_social_post(id).delete
          insert_parts(id, parts)
          by_id(id)
        end
      end

      private

      def insert_parts(social_post_id, parts)
        rows = parts.each_with_index.map { |body, index| { social_post_id:, position: index + 1, body: } }

        social_post_parts.stamped(:create, result: :many).call(rows)
      end

      def lock_due(id, time) = social_posts.due_at(time).by_pk(id).lock(mode: :share).one

      def lock_unclaimed(id) = unposted(id).lock.one && unclaimed(id).exist?

      def page_of(listed, page)
        ids = page.fill(listed.paged(page).pluck(:id))

        ids.with(rows: listed.where(id: ids.rows).combine(:parts, :deliveries).to_a)
      end

      def unclaimed(id) = unposted(id).unclaimed

      def unposted(id) = social_posts.by_pk(id).unposted

      def with_children = social_posts.combine(:parts, :deliveries)
    end
  end
end
