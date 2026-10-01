# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class FieldError < Blog::UI::FieldError
          SCOPE = "person"
          MESSAGES = {
            bluesky_handle: {
              "format" => ".bluesky_handle.format",
              "unreachable" => ".bluesky_handle.unreachable",
              "unresolved" => ".bluesky_handle.unresolved",
            },
            handles: { "none" => ".handles.none" },
            key: { "blank" => ".key.blank", "format" => ".key.format", "taken" => ".key.taken" },
            mastodon_handle: { "format" => ".mastodon_handle.format" },
            name: { "blank" => ".name.blank" },
          }.freeze
        end
      end
    end
  end
end
