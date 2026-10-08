# frozen_string_literal: true

module API
  module Serializers
    class SuggestionEdit < Serializer
      OPEN = %w[pending stale].freeze

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          part: Helpers::Schema.nullable({ type: "integer", description: "the part of a social post it targets" }),
          original: { type: "string", description: "the text it would replace" },
          replacement: Helpers::Schema::STRING,
          reason: Helpers::Schema::STRING,
          status: { type: "string", enum: OPEN, description: "a stale edit no longer matches the text" },
        },
      ).freeze

      schema_attributes
    end
  end
end
