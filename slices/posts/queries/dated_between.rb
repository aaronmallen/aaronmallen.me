# frozen_string_literal: true

module Posts
  module Queries
    class DatedBetween
      include Deps[post_repo: "repos.post_repo"]

      def call(from:, to:, page:) = post_repo.dated_between(from:, to:, page:)
    end
  end
end
