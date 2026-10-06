# frozen_string_literal: true

module API
  module Serializers
    class SuggestionEdit < Serializer
      OPEN = %w[pending stale].freeze

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          part: Schema.nullable({ type: "integer", description: "the part of a social post it targets" }),
          original: { type: "string", description: "the text it would replace" },
          replacement: Schema::STRING,
          reason: Schema::STRING,
          status: { type: "string", enum: OPEN, description: "a stale edit no longer matches the text" },
        },
      ).freeze

      schema_attributes
    end
  end
end
