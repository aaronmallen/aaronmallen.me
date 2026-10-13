# frozen_string_literal: true

module Mail
  module Contracts
    class SendContract < Blog::Contract
      ADDRESSES = %i[to cc bcc].freeze

      params do
        required(:from).filled(:integer)
        required(:to).filled(:array)
        required(:cc).value(:array)
        required(:bcc).value(:array)
        required(:subject).value(Blog::Types::TrimmedText, :filled?, max_size?: Blog::Constants::MAIL_SUBJECT_MAX)
        required(:body).filled(:string)
        optional(:thread).maybe(:integer)
      end

      ADDRESSES.each do |name|
        rule(name) { key.failure(FORMAT) unless value.all? { MessageContract::EMAIL.match?(it) } }
      end

      rule(:subject).validate(:without_controls, :visible)

      rule(:body) { key.failure(BLANK) unless Outgoing.text(value).match?(VISIBLE) }
    end
  end
end
