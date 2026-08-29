# frozen_string_literal: true

module Social
  module Queries
    class SyndicationUrls
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(post_id) = social_post_repo.syndication_urls(post_id)
    end
  end
end
