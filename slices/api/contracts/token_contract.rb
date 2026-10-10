# frozen_string_literal: true

module API
  module Contracts
    class TokenContract < Blog::Contract
      MAX_NAME = 100
      PAST = "past"

      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?, max_size?: MAX_NAME)
        optional(:scopes).array(Blog::Types::OAuthScope)
        optional(:expires_on).maybe(:date)
      end

      rule(:name).validate(:without_controls, :visible)

      rule(:scopes) { key.failure(BLANK) if key? && value.empty? }

      rule(:expires_on) { key.failure(PAST) if value && value <= Blog::TimeZone.today }
    end
  end
end
