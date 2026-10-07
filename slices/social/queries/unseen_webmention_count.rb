# frozen_string_literal: true

module Social
  module Queries
    class UnseenWebmentionCount
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call = webmention_repo.unseen_count
    end
  end
end
