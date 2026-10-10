# frozen_string_literal: true

module Tags
  module Contracts
    class TagContract < Blog::Contract
      NAME = Blog::Types::String.constructor { Blog::Types::TrimmedText[it].downcase }

      params do
        required(:name).filled(NAME)
        required(:color).maybe(Blog::Types::Nullable::TagColor)
      end

      rule(:name).validate(:without_controls)

      rule(:name) do
        key.failure(FORMAT) unless rule_error?(:name) || Blog::Types::Tag.valid?(value)
      end
    end
  end
end
