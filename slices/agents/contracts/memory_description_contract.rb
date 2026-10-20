# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryDescriptionContract < AuthorContract
      DESCRIPTION = Dry::Schema.Params do
        required(:description).filled(Blog::Types::TrimmedText, format?: /\A[^\r\n]*\z/)
      end

      params(AUTHOR, DESCRIPTION)

      rule(:description).validate(:without_controls, :visible)
    end
  end
end
