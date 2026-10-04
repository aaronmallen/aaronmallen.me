# frozen_string_literal: true

module API
  module Serializers
    class Attention < Serializer
      CARRIED = Blog::Types::AttentionKind["carried"]

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values },
          record_id: Schema.nullable(Schema::INTEGER),
          title: Schema.nullable(Schema::STRING),
          carried_count: Schema.nullable(Schema::INTEGER),
          days: Schema.nullable(Schema::INTEGER),
        },
      ).freeze

      attributes :kind, :record_id, :title, :carried_count, :days

      def carried_count(row) = carried?(row) ? row.days : nil

      def days(row) = carried?(row) ? nil : row.days

      private

      def carried?(row) = row.kind == CARRIED
    end
  end
end
