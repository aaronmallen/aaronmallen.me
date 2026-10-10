# frozen_string_literal: true

module API
  module Serializers
    class Attention < Serializer
      BROKEN_LINK = Blog::Types::AttentionKind["broken_link"]
      CARRIED = Blog::Types::AttentionKind["carried"]

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values },
          record_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          title: Helpers::Schema.nullable(Helpers::Schema::STRING),
          carried_count: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          days: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          post_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER).merge(description: "a broken link's post"),
          url: Helpers::Schema.nullable(Helpers::Schema::STRING).merge(description: "a broken link's URL"),
          reason: Helpers::Schema.nullable(Helpers::Schema::STRING).merge(description: "why a broken link failed"),
          failures: Helpers::Schema.nullable(Helpers::Schema::INTEGER).merge(
            description: "how many weekly checks in a row a broken link has failed",
          ),
        },
      ).freeze

      schema_attributes

      def carried_count(row) = row.kind == CARRIED ? row.days : nil

      def days(row) = counted?(row) ? nil : row.days

      def failures(row) = row.kind == BROKEN_LINK ? row.days : nil

      private

      def counted?(row) = [CARRIED, BROKEN_LINK].include?(row.kind)
    end
  end
end
