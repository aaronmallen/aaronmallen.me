# frozen_string_literal: true

module Social
  module Queries
    class PendingWebmentions
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(limit:) = webmention_repo.pending(limit:)
    end
  end
end
