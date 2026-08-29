# frozen_string_literal: true

module Suggestions
  module Queries
    class CreatedBetween
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(from:, to:) = suggestion_repo.created_between(from:, to:)
    end
  end
end
