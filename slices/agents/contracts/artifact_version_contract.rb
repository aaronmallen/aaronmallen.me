# frozen_string_literal: true

module Agents
  module Contracts
    class ArtifactVersionContract < AuthorContract
      NOTE_LIMIT = 200
      NOTE = Dry::Schema.Params do
        optional(:note).maybe(Blog::Types::OptionalText, max_size?: NOTE_LIMIT)
      end

      params(AUTHOR, NOTE)

      rule(:note).validate(:without_controls)
    end
  end
end
