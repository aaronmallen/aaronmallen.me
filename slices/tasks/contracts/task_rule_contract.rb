# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskRuleContract < Blog::Contract
      ONE = "one"

      params do
        required(:pattern).filled(Blog::Types::Normalized::RepoPattern)
        optional(:provider).maybe(Blog::Types::TaskSourceProvider)
        required(:tags).value(Blog::Types::TagList)
        optional(:projects).maybe(Blog::Types::IdList)
      end

      rule(:tags).validate(:tag_slugs)

      rule(:projects) { key.failure(ONE) if Array(value).size > 1 }

      rule(:tags, :projects) do
        key(:tags).failure(BLANK) if values[:tags].empty? && Array(values[:projects]).empty?
      end
    end
  end
end
