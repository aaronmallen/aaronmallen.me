# frozen_string_literal: true

module Decisions
  module Contracts
    class DecisionContract < Blog::Contract
      NOTE_LIMIT = 500

      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:problem).value(Blog::Types::Normalized::Lines, :filled?)
        optional(:note).value(Blog::Types::TrimmedText, max_size?: NOTE_LIMIT)
      end

      rule(:title).validate(:without_controls)
      rule(:problem).validate(:without_controls)
      rule(:note).validate(:without_controls)
    end
  end
end
