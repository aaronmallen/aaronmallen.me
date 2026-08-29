# frozen_string_literal: true

module Social
  module Queries
    class WebmentionsByStatus
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(status) = webmention_repo.by_status(status)
    end
  end
end
