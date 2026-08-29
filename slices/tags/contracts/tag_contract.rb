# frozen_string_literal: true

module Tags
  module Contracts
    class TagContract < Blog::Contract
      NAME = Blog::Types::Tag.constructor { Blog::Types::TrimmedText[it].downcase }

      params do
        required(:name).filled(NAME)
        required(:color).maybe(Blog::Types::Nullable::TagColor)
      end
    end
  end
end
