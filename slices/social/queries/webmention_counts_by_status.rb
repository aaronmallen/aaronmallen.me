# frozen_string_literal: true

module Social
  module Queries
    class WebmentionCountsByStatus
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call = webmention_repo.count_by_status
    end
  end
end
