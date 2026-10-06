# frozen_string_literal: true

module API
  module Serializers
    class Post < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          slug: Schema::STRING,
          status: { type: "string", enum: Blog::Types::PostStatus.values },
          published_at: Schema.nullable(Schema::STAMP),
          tags: Schema::TAGS,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :published_at, :updated_at
      tag_names
    end
  end
end
