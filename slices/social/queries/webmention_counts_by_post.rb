# frozen_string_literal: true

module Social
  module Queries
    class WebmentionCountsByPost
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(post_ids) = webmention_repo.count_by_post(post_ids)
    end
  end
end
