# frozen_string_literal: true

module Social
  module Queries
    class WebmentionsByStatus
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(status, page) = webmention_repo.page_by_status(status, page)
    end
  end
end
