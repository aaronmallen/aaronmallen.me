# frozen_string_literal: true

module Record
  module Contracts
    class JournalEditContract < Blog::Contract
      params do
        required(:body).value(Blog::Types::TrimmedText, :filled?)
        required(:tags).value(Blog::Types::TagList)
      end

      rule(:body).validate(:without_controls, :visible)
      rule(:tags).validate(:tag_slugs)
    end
  end
end
