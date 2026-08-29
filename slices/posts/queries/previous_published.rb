# frozen_string_literal: true

module Posts
  module Queries
    class PreviousPublished
      include Deps[post_repo: "repos.post_repo"]

      def call(post) = post_repo.previous_published(post)
    end
  end
end
