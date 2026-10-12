# frozen_string_literal: true

module Mail
  module Contracts
    class BulkContract < Blog::BulkContract
      ACT = Blog::Types::MessageBulkAction
      LABEL = /\A\d+:.+\z/
      TAGGING = [ACT["tag"], ACT["untag"]].freeze

      params do
        required(:act).value(ACT)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
        optional(:to).maybe(Blog::Types::Nullable::MailMove)
        optional(:label).maybe(Blog::Types::OptionalText)
      end

      rule(:act, :tag).validate(tag_for: TAGGING)

      rule(:to) { key.failure(BLANK) if values[:act] == ACT["move"] && value.nil? }

      rule(:label) { key.failure(FORMAT) if values[:act] == ACT["label"] && !LABEL.match?(value.to_s) }
    end
  end
end
