# frozen_string_literal: true

module Posts
  module Repos
    class PostQueries < Blog::DB::Repo
      ALL = Blog::Types::PostFilter["all"]
      BROKEN = Blog::Types::PostFilter["broken"]
      FEED_VERSION = %i[id published_at updated_at].freeze
      LINKS = %i[id body_html].freeze
      LIST = %i[id title slug published_at read_time summary first_paragraph].freeze
      PAGER = %i[title slug published_at].freeze
      PUBLIC_TAG = Blog::Types::TagScope["public"]
      RELATED = 3
      RELATED_TERMS = 16
      SITEMAP = %i[id slug published_at updated_at].freeze
      SUMMARY = %i[id title slug webmentions_enabled].freeze
      WEBMENTION_TARGET = %i[id webmentions_enabled].freeze

      def all = with_tags.newest_first.to_a

      def bodies(ids) = posts.select(*LINKS).with_ids(ids).to_a.to_h { [it.id, it.body_html] }

      def by_filter(filter, page) = page.fill(filtered(filter).newest_first.paged(page).to_a)

      def by_id(id) = with_tags.by_pk(id).one

      def by_ids(ids) = posts.lean.with_ids(ids).newest_first.to_a

      def by_tag(tag) = posts.lean.tagged(tag).newest_first.to_a

      def calendar_between(from:, to:)
        posts.lean.scheduled_or_published.dated_between(*Blog::TimeZone.day_bounds(from, to)).oldest_first.to_a
      end

      def count_by_status = posts.tally(:status)

      def count_dated_between(from:, to:)
        posts.dated_between(*Blog::TimeZone.day_bounds(from, to)).tally(:status, Blog::Types::PostStatus.values)
      end

      def dated_between(from:, to:, page:, status: nil)
        found = posts.lean.dated_between(*Blog::TimeZone.day_bounds(from, to))
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

      def failing_links(post_ids)
        post_link_checks.failing.where(post_id: post_ids).order(Sequel.desc(:failures), :url).to_a.group_by(&:post_id)
      end

      def held_follow_ups = held_post_follow_ups.oldest_first.to_a

      def last_link_check_run = link_check_runs.order(Sequel.desc(:started_at)).limit(1).one

      def link_check_tally
        post_ids = failing_checks.pluck(:post_id)

        { links: post_ids.size, posts: post_ids.uniq.size }
      end

      def link_checks(post_id) = post_link_checks.where(post_id:).to_a.to_h { [it.url, it] }

      def next_published(post) = pager(posts.published.newer_than(post).oldest_first)

      def next_scheduled = posts.scheduled.oldest_first.select(:id, :published_at).limit(1).one

      def previous_published(post) = pager(posts.published.older_than(post).newest_first)

      def published(limit = nil) = listed.published.newest_first.limit(limit).to_a

      def published_bodies = posts.select(*LINKS).published.to_a

      def published_body(id) = posts.select(*LINKS).published.by_pk(id).one

      def published_by_slug(slug) = with_tags.published.with_slug(slug).one

      def published_page(page) = page.fill(listed.published.newest_first.paged(page).to_a)

      def published_page_by_tag(tag, page) = page.fill(listed.published.tagged(tag).newest_first.paged(page).to_a)

      def published_slug?(slug) = posts.published.with_slug(slug).exist?

      def published_tag?(tag) = posts.published.tagged(tag).select(:id).exist?

      def published_tag_counts
        tags.where(scope: PUBLIC_TAG).ranked_by(post_tags.counts(posts.published.select(:id).dataset)).to_a
      end

      def published_tag_names
        tagged = post_tags.where(post_id: posts.published.select(:id).dataset).select(:tag_id)

        tags.where(id: tagged.dataset).pluck(:name).sort
      end

      def published_versions(page) = page.fill(versions.published.newest_first.paged(page).to_a)

      def published_versions_by_tag(tag, page)
        page.fill(versions.published.tagged(tag).newest_first.paged(page).to_a)
      end

      def related(post)
        others = listed.published.without(post.id)
        tagged = others.sharing_tags_with(post.id).limit(RELATED).to_a
        return tagged if tagged.length == RELATED

        tagged + worded_like(post, others.without(tagged.map(&:id))).limit(RELATED - tagged.length).to_a
      end

      def shown?(ids) = posts.with_ids(ids).scheduled_or_published.exist?

      def sitemap_posts = posts.published.newest_first.select(*SITEMAP).to_a

      def slugs(ids) = posts.with_ids(ids).select(:id, :slug).to_a.to_h { [it.id, it.slug] }

      def summaries = posts.newest_first.select(*SUMMARY).to_a

      def webmention_target(slug) = posts.select(*WEBMENTION_TARGET).published.with_slug(slug).one

      private

      def failing_checks = post_link_checks.failing.where(post_id: posts.published.select(:id).dataset.unordered)

      def filtered(filter)
        case filter
          when ALL then posts.lean
          when BROKEN then posts.lean.published.with_ids(failing_checks.select(:post_id).dataset.unordered)
          else posts.lean.with_status(filter)
        end
      end

      def listed = posts.select(*LIST).combine(:tags)

      def pager(found) = found.select(*PAGER).limit(1).one

      def versions = posts.select(*FEED_VERSION).combine(:tags)

      def with_tags = posts.combine(:tags)

      def worded_like(post, others) = others.worded_like(posts.top_terms(post.id, RELATED_TERMS))
    end
  end
end
