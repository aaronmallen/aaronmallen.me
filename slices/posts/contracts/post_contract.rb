# frozen_string_literal: true

module Posts
  module Contracts
    class PostContract < PostSeoContract
      ANNOUNCEMENT_TOO_LONG = "announcement_too_long"
      BLANK = "blank"
      EDIT_NOTE_LIMIT = 500
      PUBLISH = Blog::Types::PostIntent["publish"]
      TOO_LONG = "too_long"

      include Deps[
        announcement: "operations.compose_announcement",
        link_tagger: "social.links.tagger",
        networks: "social.networks.all",
      ]

      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:slug).maybe(Blog::Types::Nullable::Slug)
        required(:tags).value(Blog::Types::TagList)
        required(:summary).value(Blog::Types::TrimmedText)
        required(:body).value(Blog::Types::Text)
        required(:publish_at).value(Blog::Types::LocalTime)
        optional(:syndication_body).value(Blog::Types::TrimmedText)
        optional(:syndication_enabled).value(Blog::Types::Checkbox)
        optional(:syndication_targets).value(Blog::Types::Normalized::Networks)
        optional(:webmentions_enabled).value(Blog::Types::Checkbox)
        optional(:edit_note).value(Blog::Types::TrimmedText, max_size?: EDIT_NOTE_LIMIT)
      end

      rule(:slug, :title) do
        key(:slug).failure(BLANK) if values[:slug].nil?
      end

      rule(:title).validate(:without_controls)
      rule(:summary).validate(:without_controls)
      rule(:body).validate(:without_controls)
      rule(:syndication_body).validate(:without_controls)
      rule(:edit_note).validate(:without_controls)
      rule(:tags).validate(:tag_slugs)

      rule(:publish_at) do
        next if value.nil? || value.is_a?(Time)

        key.failure(value == Blog::Constants::GAP ? SKIPPED : FORMAT)
      end

      rule(:syndication_body, :syndication_enabled, :syndication_targets, :slug, :title) do |context:|
        next unless context[:intent] == PUBLISH && values[:syndication_enabled]

        typed = Blog::Types::Text[values[:syndication_body]]
        body = announcement.compose(body: typed, slug: values[:slug], title: values[:title])
        fits = values[:syndication_targets].to_a.all? do |name|
          networks.fetch(name).within_limit?(link_tagger.call(body, name))
        end
        next if fits

        key(:syndication_body).failure(typed.strip.empty? ? ANNOUNCEMENT_TOO_LONG : TOO_LONG)
      end
    end
  end
end
