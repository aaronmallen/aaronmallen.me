# frozen_string_literal: true

module API
  module Serializers
    class Link < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::RecordKind.values },
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          day: Helpers::Schema.nullable(Helpers::Schema::DAY),
          url: Helpers::Schema.nullable({ type: "string", description: "the record's page in the admin" }),
        },
      ).freeze

      GROUPS = Helpers::Schema.object(
        {},
        optional: Blog::Types::RecordKind.values.to_h { [it.to_sym, Helpers::Schema.list(reference)] },
      ).freeze

      schema_attributes

      def day(link) = super(link.day)
    end
  end
end
