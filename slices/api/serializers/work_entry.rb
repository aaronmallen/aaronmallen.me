# frozen_string_literal: true

module API
  module Serializers
    class WorkEntry < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          org: Schema::STRING,
          role: Schema::STRING,
          blurb: Schema.nullable(Schema::STRING),
          from_year: Schema::INTEGER,
          to_year: Schema.nullable({ type: "integer", description: "the last year held; null while still held" }),
          current: { type: "boolean", description: "true while the role is still held" },
        },
      ).freeze

      schema_attributes
      attribute :current, &:current?
    end
  end
end
