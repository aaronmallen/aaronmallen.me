# frozen_string_literal: true

module Suggestions
  module Contracts
    class EditsContract < Blog::Contract
      LIMITS = {
        original: Types::MAX_TEXT,
        reason: Types::MAX_REASON,
        replacement: Types::MAX_TEXT,
      }.freeze

      params do
        required(:edits).value(:array, max_size?: Types::MAX_EDITS).each(:hash) do
          required(:original).value(Blog::Types::Text, format?: VISIBLE, max_size?: LIMITS[:original])
          required(:reason).value(Blog::Types::Text, format?: VISIBLE, max_size?: LIMITS[:reason])
          required(:replacement).value(Blog::Types::Text, max_size?: LIMITS[:replacement])
          optional(:part).value(:integer)
        end
      end

      rule(:edits).each do |index:|
        LIMITS.each_key do |field|
          key([:edits, index, field]).failure(CONTROL) if value.fetch(field).match?(CONTROLS)
        end
      end
    end
  end
end
