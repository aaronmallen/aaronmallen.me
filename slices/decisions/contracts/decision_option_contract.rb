# frozen_string_literal: true

module Decisions
  module Contracts
    class DecisionOptionContract < Blog::Contract
      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:body).value(Blog::Types::Normalized::Lines)
        optional(:note).value(Blog::Types::TrimmedText, max_size?: DecisionContract::NOTE_LIMIT)
      end

      rule(:title).validate(:without_controls, :visible)
      rule(:body).validate(:without_controls)
      rule(:note).validate(:without_controls, :visible)
    end
  end
end
