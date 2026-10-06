# frozen_string_literal: true

module Posts
  module Repos
    class PostRepo < Blog::DB::Repo
      ALL = Blog::Types::PostFilter["all"]
      SUMMARY = %i[id title slug webmentions_enabled].freeze
      TAG_SCOPE = Blog::Types::TagScope["public"]

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tag(id, name)
        tag_id = tags.claim([name], scope: TAG_SCOPE).fetch(name)
        return if tagged?(id, tag_id)

        post_tags.add(id, [tag_id])
        update(id, {})
      end

      def all = with_tags.newest_first.to_a

      def by_filter(filter, page)
        listed = filter == ALL ? with_tags : with_tags.with_status(filter)

        page.fill(listed.newest_first.paged(page).to_a)
      end

      def by_id(id) = with_tags.by_pk(id).one
      def by_id_for_update(id) = posts.by_pk(id).lock.one

      def by_ids(ids) = with_tags.with_ids(ids).newest_first.to_a

      def by_status(status) = with_tags.with_status(status).newest_first.to_a

      def by_tag(tag) = with_tags.tagged(tag).newest_first.to_a

      def calendar_between(from:, to:)
        dated = with_tags.scheduled_or_published

        dated.dated_between(Blog::TimeZone.day_start(from), Blog::TimeZone.day_start(to + 1)).oldest_first.to_a
      end

      def count_by_status = posts.counts_by_status.to_a.to_h { [it.status, it.count] }

      def count_dated_between(from:, to:)
        counted = posts.dated_between(*day_bounds(from, to)).counts_by_status.to_a

        Blog::Types::PostStatus.values.to_h { [it, 0] }.merge(counted.to_h { [it.status, it.count] })
      end

      def dated_between(from:, to:, page:, status: nil)
        found = with_tags.dated_between(*day_bounds(from, to))
        found = found.with_status(status) if status

        page.fill(found.newest_first.paged(page).to_a)
      end

      def due_scheduled(time) = with_tags.due_at(time).oldest_first.to_a

      def held_follow_ups = held_post_follow_ups.oldest_first.to_a

      def hold_follow_up(**) = held_post_follow_ups.hold(**)

      def last_deleted_at = post_deletions.last_deleted_at

      def last_untagged_at = post_tag_removals.last_removed_at

      def locked_by_id(id) = by_id_for_update(id) && by_id(id)

      def next_published(post) = with_tags.published.newer_than(post).oldest_first.limit(1).one

      def previous_published(post) = with_tags.published.older_than(post).newest_first.limit(1).one

      def publish(id, at:) = publish_where(posts.by_pk(id).unpublished, id, at)

      def publish_due(id, at:) = publish_where(posts.by_pk(id).due_at(at), id, at)

      def published(limit = nil) = with_tags.published.newest_first.limit(limit).to_a

      def published_by_slug(slug) = with_tags.published.with_slug(slug).one

      def published_page(page) = page.fill(with_tags.published.newest_first.paged(page).to_a)

      def published_page_by_tag(tag, page) = page.fill(with_tags.published.tagged(tag).newest_first.paged(page).to_a)

      def release_follow_up(id) = held_post_follow_ups.by_pk(id).delete

      def replace_tags(id, names) = post_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def scheduled = with_tags.scheduled.oldest_first.to_a

      def summaries = posts.newest_first.select(*SUMMARY).to_a

      private

      def day_bounds(from, to) = [from && Blog::TimeZone.day_start(from), to && Blog::TimeZone.day_start(to + 1)]

      def publish_where(candidates, id, at)
        by_id(id) if candidates.publish(at).any?
      end

      def tagged?(id, tag_id) = post_tags.for_owner(id).where(tag_id:).exist?

      def with_tags = posts.combine(:tags)
    end
  end
end
