# frozen_string_literal: true

module Posts
  module Contracts
    class BulkContract < Blog::Contract
      BLANK = "blank"
      MAX_IDS = 100
      TAG = Blog::Types::PostBulkAction["tag"]

      params do
        required(:act).value(Blog::Types::PostBulkAction)
        required(:ids).value(Blog::Types::IdList, :filled?, max_size?: MAX_IDS)
        optional(:tag).maybe(Blog::Types::Nullable::Tag)
      end

      rule(:act, :tag) do
        next unless values[:act] == TAG

        key(:tag).failure(BLANK) if values[:tag].nil?
        key(:tag).failure(FORMAT) unless values[:tag].nil? || Blog::Types::Tag.valid?(values[:tag])
      end
    end
  end
end
