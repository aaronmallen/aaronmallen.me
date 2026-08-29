# frozen_string_literal: true

module Contact
  module Contracts
    class MessageContract < Blog::Contract
      EMAIL = /\A[^@\s]+@[^@\s.]+(?:\.[^@\s.]+)+\z/

      params do
        required(:reply_to).value(
          Blog::Types::TrimmedText, :filled?, max_size?: MessageLimits::MAX_REPLY_TO, format?: EMAIL,
        )
        required(:subject).value(Blog::Types::TrimmedText, :filled?, max_size?: MessageLimits::MAX_SUBJECT)
        required(:body).value(Blog::Types::TrimmedText, :filled?, max_size?: MessageLimits::MAX_BODY)
      end

      rule(:reply_to).validate(:without_controls)
      rule(:subject).validate(:without_controls)
      rule(:body).validate(:without_controls)
    end
  end
end
