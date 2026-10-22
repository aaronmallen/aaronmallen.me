# frozen_string_literal: true

module API
  module Serializers
    class Person < Serializer
      TEXT = Helpers::Schema.nullable(Helpers::Schema::STRING)
      TYPED = Helpers::Schema.list(
        Helpers::Schema.object({ value: Helpers::Schema::STRING }, optional: { type: TEXT }),
      ).freeze
      ADDRESS = %i[street extended city region postal_code country type].to_h { [it, TEXT] }.freeze

      OPEN = {
        id: Helpers::Schema::INTEGER,
        key: Helpers::Schema.nullable(
          { type: "string", description: "the token a post mentions them by, as @{key}; null without a handle" },
        ),
        name: TEXT,
        mastodon_handle: TEXT,
        bluesky_handle: TEXT,
      }.freeze

      PRIVATE = {
        **(Contacts::Contracts::PersonContract::TEXTS - [:name]).to_h { [it, TEXT] },
        **%i[emails phones websites chats dates relations].to_h { [it, TYPED] },
        addresses: Helpers::Schema.list(Helpers::Schema.object({}, optional: ADDRESS)),
        custom_fields: Helpers::Schema.list(
          Helpers::Schema.object({ key: Helpers::Schema::STRING, value: Helpers::Schema::STRING }),
        ),
        birthday: Helpers::Schema.nullable(
          { type: "string", description: "YYYY-MM-DD, or --MM-DD when the year is unknown" },
        ),
        labels: Helpers::Schema.list(Helpers::Schema::STRING),
        starred: Helpers::Schema::BOOLEAN,
        created_at: Helpers::Schema::STAMP,
        updated_at: Helpers::Schema::STAMP,
      }.freeze

      SCHEMA = Helpers::Schema.object(OPEN, optional: PRIVATE).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def labels(person) = person.labels.to_a
    end
  end
end
