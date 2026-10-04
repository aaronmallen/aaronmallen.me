# frozen_string_literal: true

module Posts
  module Queries
    class LastUntaggedAt
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.last_untagged_at
    end
  end
end
