# frozen_string_literal: true

module API
  module Serializers
    class Share < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          code: { type: "string", description: "the share's short code on the share host" },
          url: { type: "string", description: "the link that returns the file" },
          filename: Helpers::Schema::STRING,
          content_type: Helpers::Schema::STRING,
          byte_size: Helpers::Schema::INTEGER,
          alt_text: Helpers::Schema.nullable(Helpers::Schema::STRING),
          download_count: Helpers::Schema::INTEGER,
          created_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at

      def url(share) = params.fetch(:settings).share_url(share.short)
    end
  end
end
