# frozen_string_literal: true

module Tasks
  module Contracts
    class BulkContract < Blog::BulkContract
      MOVE = Blog::Types::TaskBulkAction["move"]
      TAGGING = [Blog::Types::TaskBulkAction["tag"], Blog::Types::TaskBulkAction["untag"]].freeze

      params do
        required(:act).value(Blog::Types::TaskBulkAction)
        optional(:to).maybe(Blog::Types::Nullable::TaskFilter)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :to) do
        key(:to).failure(BLANK) if values[:act] == MOVE && values[:to].nil?
      end

      rule(:act, :tag).validate(tag_for: TAGGING)
    end
  end
end
