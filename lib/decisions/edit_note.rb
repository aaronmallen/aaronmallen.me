# frozen_string_literal: true

require "dry/monads"

module Decisions
  module EditNote
    extend Dry::Monads[:result]

    def self.call(needed:, note:)
      return Success(nil) unless needed
      return Failure([:invalid, { note: [Blog::Contract::BLANK] }]) if note.empty?

      Success(note)
    end
  end
end
