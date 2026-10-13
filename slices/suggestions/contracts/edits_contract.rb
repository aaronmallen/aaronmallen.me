# frozen_string_literal: true

module Suggestions
  module Contracts
    class EditsContract < Blog::Contract
      LIMITS = {
        original: Blog::Constants::SUGGESTION_TEXT_MAX,
        reason: Blog::Constants::SUGGESTION_REASON_MAX,
        replacement: Blog::Constants::SUGGESTION_TEXT_MAX,
      }.freeze

      params do
        required(:edits).value(:array, max_size?: Blog::Constants::SUGGESTION_EDITS_MAX).each(:hash) do
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
