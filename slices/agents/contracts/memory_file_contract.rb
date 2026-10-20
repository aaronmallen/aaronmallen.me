# frozen_string_literal: true

module Agents
  module Contracts
    class MemoryFileContract < MemoryScopeContract
      PATH = Blog::Types::String.constructor do |value|
        path = Blog::Types::TrimmedText[value.to_s]
        path.end_with?(".md") ? path : "#{path}.md"
      end
      PATH_FORMAT = %r{\A[\w./-]+\.md\z}

      params(AUTHOR, SCOPE, MemoryDescriptionContract::DESCRIPTION) do
        required(:path).filled(PATH, format?: PATH_FORMAT)
      end

      rule(:description).validate(:without_controls, :visible)
    end
  end
end
