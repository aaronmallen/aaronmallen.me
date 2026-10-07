# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskRuleContract < Blog::Contract
      params do
        required(:pattern).filled(Blog::Types::Normalized::RepoPattern)
        optional(:provider).maybe(Blog::Types::TaskSourceProvider)
        required(:tags).value(Blog::Types::TagList)
        optional(:projects).maybe(Blog::Types::IdList)
      end

      rule(:tags).validate(:tag_slugs)

      rule(:tags, :projects) do
        key(:tags).failure(BLANK) if values[:tags].empty? && Array(values[:projects]).empty?
      end
    end
  end
end
