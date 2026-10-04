# frozen_string_literal: true

module Social
  module Contracts
    class PersonContract < Blog::Contract
      BLUESKY_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]\z/
      MASTODON_FORMAT = /\A@\w+(?:[.-]\w+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]\z/i
      NONE = "none"

      BLUESKY_HANDLE = Blog::Types::String.constrained(format: BLUESKY_FORMAT).optional.constructor do |value|
        Blog::Types::OptionalText[value]&.delete_prefix("@")&.downcase
      end
      KEY = Blog::Types::Tag.constructor { Blog::Types::TrimmedText[it].downcase }
      MASTODON_HANDLE = Blog::Types::String.constrained(format: MASTODON_FORMAT).optional.constructor do |value|
        Blog::Types::OptionalText[value]
      end

      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?)
        required(:key).filled(KEY)
        required(:mastodon_handle).maybe(MASTODON_HANDLE)
        required(:bluesky_handle).maybe(BLUESKY_HANDLE)
      end

      rule(:name).validate(:without_controls, :visible)

      rule(:mastodon_handle, :bluesky_handle) do
        key(:handles).failure(NONE) unless values[:mastodon_handle] || values[:bluesky_handle]
      end
    end
  end
end
