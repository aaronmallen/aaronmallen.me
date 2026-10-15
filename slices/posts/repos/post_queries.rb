# frozen_string_literal: true

module Posts
  module Repos
    class PostQueries < Blog::DB::Repo
      ALL = Blog::Types::PostFilter["all"]
      FEED_VERSION = %i[id published_at updated_at].freeze
      LINKS = %i[id body].freeze
      LIST = %i[id title slug published_at read_time summary first_paragraph].freeze
      PAGER = %i[title slug published_at].freeze
      SITEMAP = %i[id slug published_at updated_at].freeze
      SUMMARY = %i[id title slug webmentions_enabled].freeze

      def all = with_tags.newest_first.to_a

      def by_filter(filter, page)
        listed = filter == ALL ? with_tags : with_tags.with_status(filter)

        page.fill(listed.newest_first.paged(page).to_a)
      end

      def by_id(id) = with_tags.by_pk(id).one

      def by_ids(ids) = with_tags.with_ids(ids).newest_first.to_a

      def by_status(status) = with_tags.with_status(status).newest_first.to_a

      def by_tag(tag) = with_tags.tagged(tag).newest_first.to_a

      def calendar_between(from:, to:)
        dated = with_tags.scheduled_or_published

        dated.dated_between(*Blog::TimeZone.day_bounds(from, to)).oldest_first.to_a
      end

      def count_by_status = posts.tally(:status)

      def count_dated_between(from:, to:)
        posts.dated_between(*Blog::TimeZone.day_bounds(from, to)).tally(:status, Blog::Types::PostStatus.values)
      end

      def dated_between(from:, to:, page:, status: nil)
        found = with_tags.dated_between(*Blog::TimeZone.day_bounds(from, to))
        found = found.with_status(status) if status

        page.fill(found.newest_first.paged(page).to_a)
      end

      def due_scheduled(time) = with_tags.due_at(time).oldest_first.to_a

      def edit_notes(post_id) = post_edits.for_post(post_id).pluck(:note)

      def edit_on_post?(post_id, id) = post_edits.for_post(post_id).by_pk(id).exist?

      def edited_at(post_ids) = post_edits.edited_at(post_ids).to_a.to_h { [it.post_id, it.edited_at] }

      def edits_for_post(post_id) = post_edits.for_post(post_id).oldest_first.to_a

      def edits_for_posts(post_ids) = post_edits.for_posts(post_ids).oldest_first.to_a.group_by(&:post_id)

      def edits_newest_first(post_id) = edits_for_post(post_id).reverse

      def held_follow_ups = held_post_follow_ups.oldest_first.to_a

      def last_changed_published_at(tag = nil)
        published = posts.published
        (tag ? published.tagged(tag) : published).last_changed_at
      end

      def last_deleted_at = post_deletions.last_deleted_at

      def last_untagged_at = post_tag_removals.last_removed_at

      def next_published(post) = pager(posts.published.newer_than(post).oldest_first)

      def next_scheduled = posts.scheduled.oldest_first.select(:id, :published_at).limit(1).one

      def previous_published(post) = pager(posts.published.older_than(post).newest_first)

      def published(limit = nil) = listed.published.newest_first.limit(limit).to_a

      def published_bodies = posts.select(*LINKS).published.to_a

      def published_by_ids(ids) = with_tags.published.with_ids(ids).newest_first.to_a

      def published_by_slug(slug) = with_tags.published.with_slug(slug).one

      def published_page(page) = page.fill(listed.published.newest_first.paged(page).to_a)

      def published_page_by_tag(tag, page) = page.fill(listed.published.tagged(tag).newest_first.paged(page).to_a)

      def published_slug?(slug) = posts.published.with_slug(slug).exist?

      def published_tag_names
        tagged = post_tags.where(post_id: posts.published.select(:id).dataset).select(:tag_id)

        tags.where(id: tagged.dataset).pluck(:name).sort
      end

      def published_versions(page) = page.fill(versions.published.newest_first.paged(page).to_a)

      def published_versions_by_tag(tag, page)
        page.fill(versions.published.tagged(tag).newest_first.paged(page).to_a)
      end

      def shown?(ids) = posts.with_ids(ids).scheduled_or_published.exist?

      def sitemap_posts = posts.published.newest_first.select(*SITEMAP).to_a

      def slugs(ids) = posts.with_ids(ids).select(:id, :slug).to_a.to_h { [it.id, it.slug] }

      def summaries = posts.newest_first.select(*SUMMARY).to_a

      private

      def listed = posts.select(*LIST).combine(:tags)

      def pager(found) = found.select(*PAGER).limit(1).one

      def versions = posts.select(*FEED_VERSION).combine(:tags)

      def with_tags = posts.combine(:tags)
    end
  end
end
