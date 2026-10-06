# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskContract < Blog::Contract
      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:list).maybe(Blog::Types::Nullable::TaskFilter)
        required(:note).value(Blog::Types::TrimmedText)
        required(:tags).value(Blog::Types::TagList)
        optional(:contributors).value(:array)
      end

      rule(:contributors) do
        key.failure(FORMAT) if key? && !value.all? { Blog::Types::Contributor.valid?(it) }
      end

      rule(:title).validate(:without_controls, :visible)
      rule(:note).validate(:without_controls)
      rule(:tags).validate(:tag_slugs)
    end
  end
end
