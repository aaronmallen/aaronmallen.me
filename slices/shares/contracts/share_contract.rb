# frozen_string_literal: true

module Shares
  module Contracts
    class ShareContract < Blog::Contract
      CODE = Blog::Types::String.constructor { Blog::Types::TrimmedText[it].downcase }

      params do
        optional(:code).filled(CODE)
        optional(:alt_text).maybe(Blog::Types::OptionalText)
      end

      rule(:code) do
        key.failure(FORMAT) if key? && !Blog::Types::ShortCode.valid?(value)
      end

      rule(:alt_text).validate(:without_controls)
    end
  end
end
