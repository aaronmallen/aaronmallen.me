# frozen_string_literal: true

module Tags
  module Queries
    class MatchingCount
      include Deps[tag_repo: "repos.tag_repo"]

      def call(scope:, text:) = tag_repo.count_matching(scope, text)
    end
  end
end
