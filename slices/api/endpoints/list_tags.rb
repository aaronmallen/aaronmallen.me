# frozen_string_literal: true

module API
  module Endpoints
    class ListTags < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Blog::Helpers::Paging::PAGE,
          query: { type: "string", description: "part of a tag's name; only tags whose name holds it come back" },
          scope: TagEndpoint::SCOPE,
        },
        required: ["scope"],
      }.freeze

      TAG = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          scope: { type: "string", enum: Blog::Types::TagScope.values },
          color: Helpers::Schema::STRING,
          count: { type: "integer", description: "how many records carry it" },
          by_kind: {
            type: "object",
            additionalProperties: Helpers::Schema::INTEGER,
            description: "that count split by kind of record",
          },
        },
      ).freeze

      REPLY = Helpers::Schema.paged(
        {
          tags: Helpers::Schema.list(TAG),
          count: { type: "integer", description: "how many tags match" },
        },
      ).freeze

      include Deps[tag_queries: "tags.repos.tag_queries"]

      def handle(scope:, page: 1, query: nil)
        text = Blog::Types::TrimmedText[query].downcase
        usage = tag_queries.usage(scope:)
        tags = tag_queries.page_matching(scope, text, page_of(page))

        Success(
          tags: tags.rows.map { summary(it, usage.fetch(it.id, Blog::Constants::EMPTY_HASH)) },
          count: tag_queries.count_matching(scope, text),
          **Blog::Helpers::Paging.fields(tags),
        )
      end

      private

      def summary(tag, held)
        { id: tag.id, name: tag.name, scope: tag.scope, color: tag.color, count: held.values.sum, by_kind: held }
      end
    end
  end
end
