# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module People
      CONFLICT = "Google changed this contact first, so nothing changed; read it again and redo the edit"
      FIELDS = %i[name key mastodon_handle bluesky_handle].freeze
      GOOGLE_DOWN = "Google did not take the change, so nothing changed; try again soon"
      ID = Helpers::Schema::ID
      MENTIONED = "scheduled social post %s, which mentions @{%s},"
      UNSAVED = "could not save the person"

      CONTRACTS = [::Contacts::Contracts::PersonContract].freeze
      COMPLAINTS = {
        bluesky_handle: {
          Blog::Contract::FORMAT => "a Bluesky handle looks like ada.bsky.social",
          "unreachable" => "Bluesky did not answer; try again in a moment",
          "unresolved" => "Bluesky knows no account by that handle",
        },
        key: {
          Blog::Contract::BLANK => "give a person with a handle a key",
          Blog::Contract::FORMAT => "a key is lowercase words joined by hyphens",
          "taken" => "someone else already holds that key",
        },
        mastodon_handle: { Blog::Contract::FORMAT => "a Mastodon handle looks like @ada@ruby.social" },
        name: { Blog::Contract::BLANK => "give the person a name" },
      }.freeze

      BLUESKY_HANDLE = [
        "their Bluesky handle, such as ada.bsky.social, which saving looks up on Bluesky;",
        "null clears it",
      ].join(" ").freeze

      PROPERTIES = {
        name: { type: "string", description: "the person's name" },
        key: {
          type: "string",
          description: [
            "the token a post mentions them by, as @{key}: lowercase words joined by hyphens;",
            "needed once they have a handle",
          ].join(" "),
        },
        mastodon_handle: Helpers::Schema.nullable(
          { type: "string", description: "their Mastodon handle, such as @ada@ruby.social; null clears it" },
        ),
        bluesky_handle: Helpers::Schema.nullable({ type: "string", description: BLUESKY_HANDLE }),
      }.freeze
    end
  end
end
