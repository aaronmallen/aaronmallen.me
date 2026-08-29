# frozen_string_literal: true

module Suggestions
  module Queries
    class ById
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(id) = suggestion_repo.by_id(id)
    end
  end
end
