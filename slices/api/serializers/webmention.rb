# frozen_string_literal: true

module API
  module Serializers
    class Webmention < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          post_id: Helpers::Schema::INTEGER,
          type: { type: "string", enum: Blog::Types::WebmentionType.values },
          status: { type: "string", enum: Blog::Types::WebmentionStatus.values },
          source_url: Helpers::Schema::STRING,
          author_name: Helpers::Schema.nullable(Helpers::Schema::STRING),
          author_url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          excerpt: Helpers::Schema.nullable(Helpers::Schema::STRING),
          spam_reason: Helpers::Schema.nullable(Helpers::Schema::STRING),
          received_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :received_at
    end
  end
end
