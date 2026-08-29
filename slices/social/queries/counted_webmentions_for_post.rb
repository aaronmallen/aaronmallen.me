# frozen_string_literal: true

module Social
  module Queries
    class CountedWebmentionsForPost
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(post_id) = webmention_repo.counted_for(post_id)
    end
  end
end
