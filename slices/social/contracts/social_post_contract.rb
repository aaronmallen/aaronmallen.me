# frozen_string_literal: true

module Social
  module Contracts
    class SocialPostContract < Blog::Contract
      DUPLICATE = "duplicate"
      MANY = "many"
      MAX_PHOTOS = 4

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
        held = photos.group_by { it[:part] }.values
        key(:photos).failure(MANY) if held.any? { it.size > MAX_PHOTOS }
        key(:photos).failure(DUPLICATE) if held.any? { |part| part.uniq { it[:key] }.size < part.size }
      end
    end
  end
end
