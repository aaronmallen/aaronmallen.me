# frozen_string_literal: true

module Posts
  module Queries
    class ByFilter
      include Deps[post_repo: "repos.post_repo"]

      def call(filter, page) = post_repo.by_filter(filter, page)
    end
  end
end
