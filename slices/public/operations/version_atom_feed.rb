# frozen_string_literal: true

require "digest"
require "json"

module Public
  module Operations
    class VersionAtomFeed
      Version = Data.define(:posts, :edited_at, :deleted_at) do
        def changed_at(post) = [post.changed_at, edited_at[post.id]].compact.max

        def etag
          entries = posts.rows.map { [it.id, changed_at(it).utc.iso8601(6), it.tags.map(&:name)] }

          %(W/"#{Digest::SHA256.hexdigest(JSON.generate([posts.more, *entries]))}")
        end

        def last_modified = [updated, deleted_at].compact.max

        def updated = posts.rows.map { changed_at(it) }.max
      end

      include Deps[edited_at: "posts.queries.edited_at", last_deleted_at: "posts.queries.last_deleted_at"]

      def call(posts)
        Version.new(posts:, edited_at: edited_at.call(posts.rows.map(&:id)), deleted_at: last_deleted_at.call)
      end
    end
  end
end
