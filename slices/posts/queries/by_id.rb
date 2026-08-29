# frozen_string_literal: true

module Posts
  module Queries
    class ById
      include Deps[post_repo: "repos.post_repo"]

      def call(id) = post_repo.by_id(id)
    end
  end
end
