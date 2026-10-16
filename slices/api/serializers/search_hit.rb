# frozen_string_literal: true

module API
  module Serializers
    class SearchHit < Serializer
      TASK = Blog::Types::SearchKind["task"]
      VISITORS = %w[commit message webmention pull_request].map { Blog::Types::SearchKind[it] }.freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::SearchKind.values },
          id: { type: "integer", description: "the record's ID, as the kind's read tool takes it" },
          title: Helpers::Schema::STRING,
          label: Helpers::Schema.nullable(
            { type: "string", description: "a task's label, KEY-n or n; null for every other kind" },
          ),
          match: { type: "string", description: "the stretch of text around the words that matched" },
          date: Helpers::Schema::DAY,
        },
      ).freeze

      schema_attributes

      def date(hit) = day(hit.day)

      def id(hit) = hit.source_id

      def match(hit) = [TASK, *VISITORS].include?(hit.kind) ? untrusted(hit.match) : hit.match

      def title(hit)
        return synced(hit.source_id, hit.title) if hit.kind == TASK

        VISITORS.include?(hit.kind) ? untrusted(hit.title) : hit.title
      end
    end
  end
end
