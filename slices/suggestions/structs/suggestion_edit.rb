# frozen_string_literal: true

module Suggestions
  module Structs
    class SuggestionEdit < Blog::DB::Struct
      FIRST_PART = 1
      PENDING = "pending"
      STALE = "stale"

      def applies_to?(body) = body.to_s.scan(original).length == 1

      def apply_to(body) = body.sub(original) { replacement }

      def open? = pending? || stale?

      def part_number = part || FIRST_PART

      def pending? = status == PENDING

      def stale? = status == STALE
    end
  end
end
