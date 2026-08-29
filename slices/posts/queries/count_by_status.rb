# frozen_string_literal: true

module Posts
  module Queries
    class CountByStatus
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.count_by_status
    end
  end
end
