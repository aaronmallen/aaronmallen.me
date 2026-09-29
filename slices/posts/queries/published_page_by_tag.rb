# frozen_string_literal: true

module Posts
  module Queries
    class PublishedPageByTag
      include Deps[post_repo: "repos.post_repo"]

      def call(tag, page) = post_repo.published_page_by_tag(tag, page)
    end
  end
end
