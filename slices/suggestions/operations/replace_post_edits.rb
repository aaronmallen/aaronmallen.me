# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplacePostEdits < Blog::Operation
      include Deps[contract: "contracts.edits_contract", suggestion_repo: "repos.suggestion_repo"]

      def call(post_id, edits:)
        attributes = step validated(contract.call(edits:))
        suggestion_repo.replace_for_post(post_id, attributes[:edits])
      end
    end
  end
end
