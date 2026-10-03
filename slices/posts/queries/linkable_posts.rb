# frozen_string_literal: true

module Posts
  module Queries
    class LinkablePosts
      include Deps[post_repo: "repos.post_repo"]

      def matching(text, limit:) = post_repo.linkable(:posts, text:, limit:)

      def named(ids) = post_repo.linkable(:posts, ids:)
    end
  end
end
