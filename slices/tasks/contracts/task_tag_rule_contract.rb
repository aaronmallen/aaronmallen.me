# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskTagRuleContract < Blog::Contract
      params do
        required(:pattern).filled(Blog::Types::Normalized::RepoPattern)
        required(:tags).value(Blog::Types::TagList, :filled?)
      end

      rule(:tags).validate(:tag_slugs)
    end
  end
end
