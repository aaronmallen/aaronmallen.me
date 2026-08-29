# frozen_string_literal: true

module Social
  module Queries
    class PendingWebmentionCount
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call = webmention_repo.pending_count
    end
  end
end
