# frozen_string_literal: true

module Tasks
  module Contracts
    class BulkContract < Blog::Contract
      BLANK = "blank"
      MAX_IDS = 100
      MOVE = Blog::Types::TaskBulkAction["move"]
      TAGGING = [Blog::Types::TaskBulkAction["tag"], Blog::Types::TaskBulkAction["untag"]].freeze

      params do
        required(:act).value(Blog::Types::TaskBulkAction)
        required(:ids).value(Blog::Types::IdList, :filled?, max_size?: MAX_IDS)
        optional(:to).maybe(Blog::Types::Nullable::TaskFilter)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :to) do
        key(:to).failure(BLANK) if values[:act] == MOVE && values[:to].nil?
      end

      rule(:act, :tag) do
        next unless TAGGING.include?(values[:act])

        key(:tag).failure(BLANK) if values[:tag].nil?
        key(:tag).failure(FORMAT) unless values[:tag].nil? || Blog::Types::Tag.valid?(values[:tag])
      end
    end
  end
end
