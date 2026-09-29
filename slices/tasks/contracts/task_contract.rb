# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskContract < Blog::Contract
      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:list).maybe(Blog::Types::Nullable::TaskFilter)
        required(:note).value(Blog::Types::TrimmedText)
        required(:tags).value(Blog::Types::TagList)
      end

      rule(:title).validate(:without_controls)
      rule(:note).validate(:without_controls)
      rule(:tags).validate(:tag_slugs)
    end
  end
end
