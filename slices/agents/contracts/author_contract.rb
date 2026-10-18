# frozen_string_literal: true

module Agents
  module Contracts
    class AuthorContract < Blog::Contract
      AUTHOR = Dry::Schema.Params do
        optional(:agent).maybe(Blog::Types::Normalized::ContributorSlug)
        optional(:model).maybe(Blog::Types::Normalized::ContributorSlug)
      end

      params(AUTHOR)

      rule(:model) do
        key(values[:model] ? :agent : :model).failure(MISSING) if values[:agent].nil? != values[:model].nil?
      end
    end
  end
end
