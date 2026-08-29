# frozen_string_literal: true

module Posts
  module Queries
    class ByStatus
      include Deps[post_repo: "repos.post_repo"]

      def call(status) = post_repo.by_status(status)
    end
  end
end
