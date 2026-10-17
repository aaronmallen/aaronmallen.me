# frozen_string_literal: true

module API
  module Serializers
    class ShareGroupFile < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          url: { type: "string", description: "the link that returns this file from its group" },
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

      def url(file) = params.fetch(:settings).share_url(params.fetch(:code), file.id)
    end
  end
end
