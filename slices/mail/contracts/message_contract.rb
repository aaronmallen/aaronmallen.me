# frozen_string_literal: true

module Mail
  module Contracts
    class MessageContract < Blog::Contract
      EMAIL = /\A[^@[:space:]]+@[^@[:space:].]+(?:\.[^@[:space:].]+)+\z/

      params do
        required(:reply_to).value(
          Blog::Types::TrimmedText, :filled?, max_size?: Types::MAX_REPLY_TO, format?: EMAIL,
        )
        required(:subject).value(Blog::Types::TrimmedText, :filled?, max_size?: Blog::Constants::MAIL_SUBJECT_MAX)
        required(:body).value(Blog::Types::Normalized::Lines, :filled?, max_size?: Blog::Constants::MAIL_BODY_MAX)
      end

      rule(:reply_to).validate(:without_controls)
      rule(:subject).validate(:without_controls, :visible)
      rule(:body).validate(:without_controls, :visible)
    end
  end
end
