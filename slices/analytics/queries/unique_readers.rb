# frozen_string_literal: true

module Analytics
  module Queries
    class UniqueReaders
      NONE = { readers: nil, final: true }.freeze
      UNREAD = { readers: 0, final: false }.freeze

      include Deps["queries.readers_by_path"]

      def call(posts, since: Readers.window_opened_at)
        counts = readers_by_path.call(posts.map { path(it) })

        posts.to_h { |post| [post.id, counts.fetch(path(post)) { counted?(post, since) ? UNREAD : NONE }] }
      end

      private

      def counted?(post, since) = post.published_at.nil? || post.published_at > since

      def path(post) = "#{Blog::Site::WRITING}/#{post.slug}"
    end
  end
end
