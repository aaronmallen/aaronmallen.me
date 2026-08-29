# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplaceSocialPostEdits < Blog::Operation
      include Deps[contract: "contracts.edits_contract", suggestion_repo: "repos.suggestion_repo"]

      def call(social_post_id, edits:)
        attributes = step validated(contract.call(edits:))
        suggestion_repo.replace_for_social_post(social_post_id, attributes[:edits])
      end
    end
  end
end
