# frozen_string_literal: true

module Suggestions
  module Operations
    class RejectEdits
      include Deps[suggestion_repo: "repos.suggestion_repo"]

      def call(ids) = suggestion_repo.reject(ids)
    end
  end
end
