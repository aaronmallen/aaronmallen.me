# frozen_string_literal: true

module Shares
  module Contracts
    class ShortLinkContract < Blog::Contract
      params do
        optional(:destination).filled(Blog::Types::TrimmedText)
        optional(:code).filled(ShareContract::CODE)
        optional(:title).maybe(Blog::Types::OptionalText)
      end

      rule(:destination) do
        key.failure(FORMAT) if key? && !Blog::Types::Url.valid?(value)
      end

      rule(:code) do
        key.failure(FORMAT) if key? && !Blog::Types::ShortCode.valid?(value)
      end

      rule(:title).validate(:without_controls)
    end
  end
end
