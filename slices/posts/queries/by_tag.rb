# frozen_string_literal: true

module Posts
  module Queries
    class ByTag
      include Deps[post_repo: "repos.post_repo"]

      def call(tag) = post_repo.by_tag(tag)
    end
  end
end
