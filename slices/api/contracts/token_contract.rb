# frozen_string_literal: true

module API
  module Contracts
    class TokenContract < Blog::Contract
      MAX_NAME = 100

      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?, max_size?: MAX_NAME)
      end

      rule(:name).validate(:without_controls)
    end
  end
end
