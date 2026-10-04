# frozen_string_literal: true

module Decisions
  module Contracts
    class DecisionCommentContract < Blog::Contract
      params do
        required(:body).value(Blog::Types::Normalized::Lines, :filled?)
      end

      rule(:body).validate(:without_controls, :visible)
    end
  end
end
