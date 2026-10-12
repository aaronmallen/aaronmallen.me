# frozen_string_literal: true

module Posts
  module Contracts
    class BulkContract < Blog::BulkContract
      TAGGING = [Blog::Types::PostBulkAction["tag"], Blog::Types::PostBulkAction["untag"]].freeze

      params do
        required(:act).value(Blog::Types::PostBulkAction)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :tag).validate(tag_for: TAGGING)
    end
  end
end
