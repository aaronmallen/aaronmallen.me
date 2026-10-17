# frozen_string_literal: true

require "digest"
require "json"

module Public
  module Operations
    class VersionAtomFeed
      Version = Data.define(:posts, :edited_at, :deleted_at, :untagged_at, :feed_changed_at) do
        def changed_at(post) = [post.changed_at, edited_at[post.id]].compact.max

        def etag
          entries = posts.rows.map { [it.id, changed_at(it).utc.iso8601(6), it.tags.map(&:name)] }

          %(W/"#{Digest::SHA256.hexdigest(JSON.generate([posts.more, *entries]))}")
        end

        def last_modified = [updated, deleted_at, untagged_at, tags_edited_at, feed_changed_at].compact.max

        def tags_edited_at
          posts.rows.flat_map(&:tags).filter_map { it.updated_at if it.updated_at > it.created_at }.max
        end

        def updated = posts.rows.map { changed_at(it) }.max
      end

      include Deps[
        feed_queries: "posts.repos.feed_queries",
      ]

      def call(posts, tag: nil)
        Version.new(posts:, **feed_queries.stamps(posts.rows.map(&:id), tag))
      end
    end
  end
end
