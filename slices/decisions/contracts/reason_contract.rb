# frozen_string_literal: true

module Decisions
  module Contracts
    class ReasonContract < Blog::Contract
      params do
        required(:reason).value(Blog::Types::Normalized::Lines, :filled?)
      end

      rule(:reason).validate(:without_controls)
    end
  end
end
