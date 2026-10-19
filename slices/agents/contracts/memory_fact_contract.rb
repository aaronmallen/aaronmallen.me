# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryFactContract < AuthorContract
      params(AUTHOR) do
        required(:type).filled(:string, included_in?: Blog::Types::MemoryFactType.values)
        required(:text).filled(Blog::Types::TrimmedText)
      end

      rule(:text).validate(:without_controls, :visible)
    end
  end
end
