# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplaceSocialPostEdits < Blog::Operation
      include Deps[contract: "contracts.edits_contract", suggestion_mutations: "repos.suggestion_mutations"]

      def call(social_post_id, edits:)
        attributes = step validated(contract.call(edits:))
        suggestion_mutations.replace_for_social_post(social_post_id, attributes[:edits])
      end
    end
  end
end
