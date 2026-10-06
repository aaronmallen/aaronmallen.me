# frozen_string_literal: true

module Social
  module Queries
    class WebmentionCountsReceivedIn
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(from:, to:, post_id: nil) = webmention_repo.count_received_in(from:, to:, post_id:)
    end
  end
end
