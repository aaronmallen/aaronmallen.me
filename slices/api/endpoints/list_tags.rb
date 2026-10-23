# frozen_string_literal: true

module API
  module Endpoints
    class ListTags < TagEndpoint
      FINDS = true
      SCOPED = true
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Helpers::Paging::PAGE,
          project: PROJECT_FIELD,
          query: { type: "string", description: "part of a tag's name; only tags whose name holds it come back" },
          scope: SCOPE,
        },
        required: ["scope"],
      }.freeze

      TAG = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: Helpers::Schema::STRING,
          scope: { type: "string", enum: Blog::Types::TagScope.values },
          color: Helpers::Schema::STRING,
          description: Helpers::Schema.nullable(Helpers::Schema::STRING),
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

      def handle(scope:, scopes:, page: 1, project: nil, query: nil)
        project_id_for(scope, project).fmap { listed(scope, it, Blog::Types::TrimmedText[query].downcase, page, scopes) }
      end

      private

      def listed(scope, project_id, text, page, scopes)
        mail = mail?(scopes)
        usage = tag_queries.usage(scope:, mail:)
        tags = tag_queries.page_matching(scope, text, page_of(page), mail:, project_id:)

        {
          tags: tags.rows.map { summary(it, usage.fetch(it.id, Blog::Constants::EMPTY_HASH)) },
          count: tag_queries.count_matching(scope, text, mail:, project_id:),
          **Helpers::Paging.fields(tags),
        }
      end

      def summary(tag, held)
        {
          id: tag.id, name: tag.name, scope: tag.scope, color: tag.color, description: tag.description,
          count: held.values.sum, by_kind: held,
        }
      end
    end
  end
end
