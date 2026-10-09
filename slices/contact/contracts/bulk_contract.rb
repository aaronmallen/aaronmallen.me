# frozen_string_literal: true

module Contact
  module Contracts
    class BulkContract < Blog::BulkContract
      TAGGING = [Blog::Types::MessageBulkAction["tag"], Blog::Types::MessageBulkAction["untag"]].freeze

      params do
        required(:act).value(Blog::Types::MessageBulkAction)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :tag).validate(tag_for: TAGGING)
    end
  end
end
