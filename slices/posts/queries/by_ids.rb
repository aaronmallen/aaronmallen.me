# frozen_string_literal: true

module Posts
  module Queries
    class ByIds
      include Deps[post_repo: "repos.post_repo"]

      def call(ids) = post_repo.by_ids(ids)
    end
  end
end
