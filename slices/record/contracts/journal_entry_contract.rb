# frozen_string_literal: true

module Record
  module Contracts
    class JournalEntryContract < Blog::Contract
      BLANK = "blank"
      ENTRY_DATE = Blog::Types::Date.optional.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        next nil if text.empty?

        Blog::TimeZone.parse_day(text) || text
      end
      FUTURE = "future"

      params do
        required(:body).value(Blog::Types::TrimmedText, :filled?)
        required(:entry_date).maybe(ENTRY_DATE)
        required(:tags).value(Blog::Types::TagList)
      end

      rule(:body).validate(:without_controls, :visible)

      rule(:entry_date) do |context:|
        next if value.nil?

        key.failure(FUTURE) if value > context.fetch(:today)
      end

      rule(:tags).validate(:tag_slugs)
    end
  end
end
