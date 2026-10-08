# frozen_string_literal: true

module API
  module Serializers
    class Person < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          key: { type: "string", description: "the token a post mentions them by, as @{key}" },
          name: Helpers::Schema::STRING,
          mastodon_handle: Helpers::Schema.nullable(Helpers::Schema::STRING),
          bluesky_handle: Helpers::Schema.nullable(Helpers::Schema::STRING),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
    end
  end
end
