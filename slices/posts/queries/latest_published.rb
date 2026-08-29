# frozen_string_literal: true

module Posts
  module Queries
    class LatestPublished
      include Deps[post_repo: "repos.post_repo"]

      def call(limit) = post_repo.published(limit)
    end
  end
end
