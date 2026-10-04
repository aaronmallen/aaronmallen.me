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

      attributes :id, :key, :name, :mastodon_handle, :bluesky_handle, :created_at, :updated_at

      def created_at(person) = stamp(person.created_at)

      def updated_at(person) = stamp(person.updated_at)
    end
  end
end
