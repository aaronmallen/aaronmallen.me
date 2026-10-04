# frozen_string_literal: true

module Record
  module Contracts
    class ReviewNoteContract < Blog::Contract
      params do
        required(:body).value(Blog::Types::TrimmedText, :filled?)
      end

      rule(:body).validate(:without_controls, :visible)
    end
  end
end
