# frozen_string_literal: true

module Posts
  module Queries
    class EditsForPosts
      include Deps[post_edit_repo: "repos.post_edit_repo"]

      def call(post_ids) = post_edit_repo.for_posts(post_ids)
    end
  end
end
