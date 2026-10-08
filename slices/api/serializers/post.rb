# frozen_string_literal: true

module API
  module Serializers
    class Post < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          slug: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::PostStatus.values },
          published_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          tags: Helpers::Schema::TAGS,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :published_at, :updated_at
      tag_names
    end
  end
end
