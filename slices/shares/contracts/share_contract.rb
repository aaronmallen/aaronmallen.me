# frozen_string_literal: true

module Shares
  module Contracts
    class ShareContract < Blog::Contract
      CODE = Blog::Types::String.constructor { Blog::Types::TrimmedText[it].downcase }

      params do
        optional(:code).filled(CODE)
        optional(:alt_text).maybe(Blog::Types::OptionalText)
        optional(:filename).filled(Blog::Types::TrimmedText)
        optional(:name).maybe(Blog::Types::OptionalText)
      end

      rule(:code) do
        key.failure(FORMAT) if key? && !Blog::Types::ShortCode.valid?(value)
      end

      %i[alt_text filename name].each { rule(it).validate(:without_controls) }
      rule(:filename).validate(:bare_filename)
    end
  end
end
