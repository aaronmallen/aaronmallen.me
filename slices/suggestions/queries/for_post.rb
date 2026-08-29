# frozen_string_literal: true

module Suggestions
  module Queries
    class ForPost
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(post_id) = suggestion_repo.for_post(post_id)
    end
  end
end
