# frozen_string_literal: true

module API
  module Serializers
    class SearchHit < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::SearchKind.values },
          id: { type: "integer", description: "the record's ID, as the kind's read tool takes it" },
          title: Helpers::Schema::STRING,
          match: { type: "string", description: "the stretch of text around the words that matched" },
          date: Helpers::Schema::DAY,
        },
      ).freeze

      schema_attributes

      def date(hit) = day(hit.day)

      def id(hit) = hit.source_id
    end
  end
end
