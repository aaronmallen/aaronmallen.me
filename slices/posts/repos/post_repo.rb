# frozen_string_literal: true

module Posts
  module Repos
    class PostRepo < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["public"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all = with_tags.newest_first.to_a

      def by_id(id) = with_tags.by_pk(id).one

      def by_id_for_update(id) = posts.by_pk(id).lock.one

      def by_ids(ids) = with_tags.with_ids(ids).newest_first.to_a

      def by_status(status) = with_tags.with_status(status).newest_first.to_a

      def count_by_status = posts.counts_by_status.to_a.to_h { [it.status, it.count] }

      def dated_between(from:, to:)
        first = from && Blog::TimeZone.day_start(from)
        last = to && Blog::TimeZone.day_start(to + 1)

        with_tags.dated_between(first, last).newest_first.to_a
      end

      def due_scheduled(time) = with_tags.due_at(time).oldest_first.to_a

      def locked_by_id(id) = by_id_for_update(id) && by_id(id)

      def next_published(post) = with_tags.published.newer_than(post).oldest_first.limit(1).one

      def previous_published(post) = with_tags.published.older_than(post).newest_first.limit(1).one

      def publish(id, at:) = publish_where(posts.by_pk(id).unpublished, id, at)

      def publish_due(id, at:) = publish_where(posts.by_pk(id).due_at(at), id, at)

      def published(limit = nil) = with_tags.published.newest_first.limit(limit).to_a

      def published_by_slug(slug) = with_tags.published.with_slug(slug).one

      def published_by_tag(tag) = with_tags.published.tagged(tag).newest_first.to_a

      def replace_tags(id, names) = post_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def scheduled = with_tags.scheduled.oldest_first.to_a

      private

      def publish_where(candidates, id, at)
        by_id(id) if candidates.publish(at).any?
      end

      def with_tags = posts.combine(:tags)
    end
  end
end
