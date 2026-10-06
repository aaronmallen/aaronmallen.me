# frozen_string_literal: true

module API
  module Serializers
    class Link < Serializer
      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::RecordKind.values },
          id: Schema::INTEGER,
          title: Schema::STRING,
          day: Schema.nullable(Schema::DAY),
          url: Schema.nullable({ type: "string", description: "the record's page in the admin" }),
        },
      ).freeze

      GROUPS = Schema.object(
        {},
        optional: Blog::Types::RecordKind.values.to_h { [it.to_sym, Schema.list(reference)] },
      ).freeze

      schema_attributes

      def day(link) = super(link.day)
    end
  end
end
