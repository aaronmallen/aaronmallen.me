# frozen_string_literal: true

module Posts
  module Queries
    class NextPublished
      include Deps[post_repo: "repos.post_repo"]

      def call(post) = post_repo.next_published(post)
    end
  end
end
