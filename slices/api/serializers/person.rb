# frozen_string_literal: true

module API
  module Serializers
    class Person < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          key: { type: "string", description: "the token a post mentions them by, as @{key}" },
          name: Schema::STRING,
          mastodon_handle: Schema.nullable(Schema::STRING),
          bluesky_handle: Schema.nullable(Schema::STRING),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
