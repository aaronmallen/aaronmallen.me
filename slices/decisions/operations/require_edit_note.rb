# frozen_string_literal: true

module Decisions
  module Operations
    class RequireEditNote < Blog::Operation
      def call(needed:, note:)
        step written(note) if needed
      end

      private

      def written(note) = note.empty? ? Failure([:invalid, { note: [Blog::Contract::BLANK] }]) : Success(note)
    end
  end
end
