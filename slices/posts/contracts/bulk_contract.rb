# frozen_string_literal: true

module Posts
  module Contracts
    class BulkContract < Blog::BulkContract
      TAG = Blog::Types::PostBulkAction["tag"]

      params do
        required(:act).value(Blog::Types::PostBulkAction)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :tag).validate(tag_for: TAG)
    end
  end
end
