# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryFactContract < AuthorContract
      TEXT_LIMIT = 1_000

      params(AUTHOR) do
        required(:type).filled(:string, included_in?: Blog::Types::MemoryFactType.values)
        required(:text).filled(Blog::Types::TrimmedText, max_size?: TEXT_LIMIT)
      end

      rule(:text).validate(:without_controls, :visible)
    end
  end
end
