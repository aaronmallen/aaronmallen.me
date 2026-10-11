# frozen_string_literal: true

module Social
  module Contracts
    class SocialPostContract < Blog::Contract
      MANY = "many"
      MAX_PHOTOS = 4
      MISSING = "missing"

      include Deps[photo_queries: "media.repos.photo_queries"]

      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        optional(:connection_ids).value(Blog::Types::IdList)
        required(:status).value(Blog::Types::SocialPostStatus)
        optional(:post_id).maybe(:integer)
        optional(:posted_at).maybe(:time)
        optional(:photos).value(:array).each(:hash) do
          required(:part).value(:integer, gt?: 0)
          required(:key).value(Blog::Types::PhotoKey)
          optional(:alt).maybe(Blog::Types::OptionalText)
        end
      end

      rule(:parts).validate(:without_controls, :visible)

      rule(:photos) do
        next unless key?

        keys = value.map { it[:key] }.uniq
        key.failure(CONTROL) if value.any? { it[:alt]&.match?(CONTROLS) }
        key.failure(MISSING) unless photo_queries.sizes(keys).size == keys.size
      end

      rule(:photos, :parts) do
        next unless key?(:photos)

        photos = values[:photos]
        key(:photos).failure(MISSING) if photos.any? { it[:part] > values[:parts].size }
        key(:photos).failure(MANY) if photos.group_by { it[:part] }.any? { |_, held| held.size > MAX_PHOTOS }
      end
    end
  end
end
