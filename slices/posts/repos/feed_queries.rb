# frozen_string_literal: true

require "time"

module Posts
  module Repos
    class FeedQueries < Blog::DB::Repo
      ENTRY = %i[id title slug summary first_paragraph body_html].freeze

      def entries(ids) = posts.select(*ENTRY).published.with_ids(ids).to_a.to_h { [it.id, it] }

      def stamps(post_ids, tag = nil)
        found = posts.dataset.db.select(*stamp_queries(post_ids, tag)).first

        found.merge(edited_at: found[:edited_at].to_h { |id, at| [id.to_i, Time.iso8601(at)] })
      end

      private

      def stamp_queries(post_ids, tag)
        published = tag ? posts.published.tagged(tag) : posts.published

        [
          post_edits.edited_at_by_post(post_ids).as(:edited_at),
          post_deletions.last_deleted_at.as(:deleted_at),
          post_tag_removals.last_removed_at.as(:untagged_at),
          published.last_changed_at.as(:feed_changed_at),
        ]
      end
    end
  end
end
