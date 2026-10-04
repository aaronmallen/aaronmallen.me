# frozen_string_literal: true

module Decisions
  module Queries
    class Comments
      include Deps[decision_comment_repo: "repos.decision_comment_repo"]

      def call(decision_id) = decision_comment_repo.oldest_first(decision_id)
    end
  end
end
