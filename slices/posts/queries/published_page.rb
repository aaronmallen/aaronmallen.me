# frozen_string_literal: true

module Posts
  module Queries
    class PublishedPage
      include Deps[post_repo: "repos.post_repo"]

      def call(page) = post_repo.published_page(page)
    end
  end
end
