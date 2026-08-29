# frozen_string_literal: true

module Posts
  module Queries
    class PublishedBySlug
      include Deps[post_repo: "repos.post_repo"]

      def call(slug) = post_repo.published_by_slug(slug)
    end
  end
end
