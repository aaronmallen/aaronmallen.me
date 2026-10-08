# frozen_string_literal: true

module API
  module Serializers
    class WorkEntry < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          org: Helpers::Schema::STRING,
          role: Helpers::Schema::STRING,
          blurb: Helpers::Schema.nullable(Helpers::Schema::STRING),
          from_year: Helpers::Schema::INTEGER,
          to_year: Helpers::Schema.nullable(
            { type: "integer", description: "the last year held; null while still held" },
          ),
          current: { type: "boolean", description: "true while the role is still held" },
        },
      ).freeze

      schema_attributes
      attribute :current, &:current?
    end
  end
end
