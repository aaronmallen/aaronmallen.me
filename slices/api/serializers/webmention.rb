# frozen_string_literal: true

module API
  module Serializers
    class Webmention < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          post_id: Schema::INTEGER,
          type: { type: "string", enum: Blog::Types::WebmentionType.values },
          status: { type: "string", enum: Blog::Types::WebmentionStatus.values },
          source_url: Schema::STRING,
          author_name: Schema.nullable(Schema::STRING),
          author_url: Schema.nullable(Schema::STRING),
          excerpt: Schema.nullable(Schema::STRING),
          spam_reason: Schema.nullable(Schema::STRING),
          received_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :received_at
    end
  end
end
