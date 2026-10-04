# frozen_string_literal: true

module Projects
  module Contracts
    class WorkEntryContract < Blog::Contract
      BEFORE_FROM = "before_from"
      FROM_YEAR = Blog::Types::Integer.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        Blog::Types::Year.valid?(text) ? text.to_i : text
      end
      TO_YEAR = Blog::Types::Integer.optional.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        next nil if text.empty?

        Blog::Types::Year.valid?(text) ? text.to_i : text
      end

      params do
        required(:org).value(Blog::Types::TrimmedText, :filled?)
        required(:role).value(Blog::Types::TrimmedText, :filled?)
        required(:blurb).maybe(Blog::Types::OptionalText)
        required(:from_year).filled(FROM_YEAR)
        required(:to_year).maybe(TO_YEAR)
      end

      rule(:org).validate(:without_controls, :visible)
      rule(:role).validate(:without_controls, :visible)
      rule(:blurb).validate(:without_controls)

      rule(:from_year, :to_year) do
        next if values[:to_year].nil?

        key(:to_year).failure(BEFORE_FROM) if values[:to_year] < values[:from_year]
      end
    end
  end
end
