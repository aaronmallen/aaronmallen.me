# frozen_string_literal: true

module API
  module Serializers
    class Attention < Serializer
      CARRIED = Blog::Types::AttentionKind["carried"]

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values },
          record_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          title: Helpers::Schema.nullable(Helpers::Schema::STRING),
          carried_count: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          days: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
        },
      ).freeze

      schema_attributes

      def carried_count(row) = carried?(row) ? row.days : nil

      def days(row) = carried?(row) ? nil : row.days

      private

      def carried?(row) = row.kind == CARRIED
    end
  end
end
