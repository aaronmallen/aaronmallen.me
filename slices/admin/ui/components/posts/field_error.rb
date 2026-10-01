# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class FieldError < Blog::UI::FieldError
          SCOPE = "post"
          MESSAGES = {
            canonical_url: { "format" => ".canonical_url.format" },
            edit_note: {
              "blank" => ".edit_note.blank",
              "control" => ".edit_note.control",
              "long" => ".edit_note.long",
            },
            og_image_url: { "format" => ".og_image_url.format" },
            publish_at: { "format" => ".publish_at.format", "skipped" => ".publish_at.skipped" },
            slug: {
              "blank" => ".slug.blank",
              "format" => ".slug.format",
              "locked" => ".slug.locked",
              "reserved" => ".slug.reserved",
              "taken" => ".slug.taken",
            },
            syndication_body: {
              "announcement_too_long" => ".syndication_body.announcement_too_long",
              "too_long" => ".syndication_body.too_long",
            },
            tags: { "format" => ".tags.format" },
            title: { "blank" => ".title.blank" },
          }.freeze
        end
      end
    end
  end
end
