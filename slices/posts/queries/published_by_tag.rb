# frozen_string_literal: true

module Posts
  module Queries
    class PublishedByTag
      include Deps[post_repo: "repos.post_repo"]

      def call(tag) = post_repo.published_by_tag(tag)
    end
  end
end
