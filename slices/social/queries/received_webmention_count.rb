# frozen_string_literal: true

module Social
  module Queries
    class ReceivedWebmentionCount
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(post_id) = webmention_repo.received_count(post_id)
    end
  end
end
