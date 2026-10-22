# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module People
      CONFLICT = "Google changed this contact first, so nothing changed; read it again and redo the edit"
      GOOGLE_DOWN = "Google did not take the change, so nothing changed; try again soon"
      ID = Helpers::Schema::ID
      MENTIONED = "scheduled social post %s, which mentions @{%s},"
      OPEN = Serializers::Person::OPEN.keys.freeze
      UNSAVED = "could not save the person"

      CONTRACTS = [::Contacts::Contracts::PersonContract].freeze
      COMPLAINTS = {
        birthday: { Blog::Contract::FORMAT => "a birthday looks like 1815-12-10, or --12-10 without the year" },
        bluesky_handle: {
          Blog::Contract::FORMAT => "a Bluesky handle looks like ada.bsky.social",
          "unreachable" => "Bluesky did not answer; try again in a moment",
          "unresolved" => "Bluesky knows no account by that handle",
        },
        dates: { Blog::Contract::FORMAT => "a date looks like 1815-12-10, or --12-10 without the year" },
        emails: { Blog::Contract::FORMAT => "an email address looks like ada@example.com" },
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

      TEXT = Helpers::Schema.nullable(Helpers::Schema::STRING)
      TYPED = Helpers::Schema.list(
        {
          type: "object",
          additionalProperties: false,
          properties: { value: Helpers::Schema::STRING, type: TEXT.merge(description: "such as home or work") },
          required: ["value"],
        },
      ).freeze

      PRIVATE = {
        name_prefix: TEXT,
        given_name: TEXT,
        middle_name: TEXT,
        family_name: TEXT,
        name_suffix: TEXT,
        phonetic_given_name: TEXT,
        phonetic_middle_name: TEXT,
        phonetic_family_name: TEXT,
        nickname: TEXT,
        file_as: TEXT.merge(description: "the name the contacts list sorts them by"),
        company: TEXT,
        job_title: TEXT,
        department: TEXT,
        notes: TEXT,
        **%i[emails phones websites chats dates relations].to_h { [it, TYPED] },
        addresses: Helpers::Schema.list(
          {
            type: "object",
            additionalProperties: false,
            properties: %i[street extended city region postal_code country type].to_h { [it, TEXT] },
          },
        ),
        custom_fields: Helpers::Schema.list(
          {
            type: "object",
            additionalProperties: false,
            properties: { key: Helpers::Schema::STRING, value: Helpers::Schema::STRING },
            required: %w[key value],
          },
        ),
        birthday: TEXT.merge(description: "YYYY-MM-DD, or --MM-DD when the year is unknown; null clears it"),
        labels: Helpers::Schema.list(Helpers::Schema::STRING).merge(description: "the whole set of labels"),
        starred: Helpers::Schema::BOOLEAN,
      }.freeze

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
        **PRIVATE,
      }.freeze

      def self.codes(found) = found.is_a?(Hash) ? found.values.flat_map { codes(it) }.uniq : found

      def self.complaints(errors)
        Helpers::Wording.complaints(errors.transform_values { codes(it) }, COMPLAINTS, named: true)
      end

      def self.contacts?(scopes) = scopes.include?(OperationTable::CONTACTS)

      def self.shown(person, scopes) = contacts?(scopes) ? person : person.slice(*OPEN.map(&:to_s))

      def self.unscoped(fields, scopes)
        Structs::Refusal.unscoped(OperationTable::CONTACTS) unless contacts?(scopes) || (fields.keys - OPEN).empty?
      end
    end
  end
end
