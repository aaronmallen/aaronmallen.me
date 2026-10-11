# frozen_string_literal: true

module MCP
  module Tools
    class ListTags < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Blog::Helpers::Paging::PAGE,
          query: { type: "string", description: "part of a tag's name; only tags whose name holds it come back" },
          scope: TAG_SCOPE,
        },
        required: ["scope"],
      }.freeze

      description "List the tags in one scope by name with their colour, how many records carry each, and that " \
                  "count split by kind. #{TAG_KINDS}. A tag nothing carries counts zero. Give query to keep only " \
                  "the tags whose name holds it; count holds how many tags match. #{Blog::Helpers::Paging::USAGE}"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(scope:, server_context:, page: 1, query: nil)
          text = Blog::Types::TrimmedText[query].downcase
          tag_queries = dep(:tag_queries, server_context)
          usage = tag_queries.usage(scope:)
          tags = tag_queries.page_matching(scope, text, page(page, server_context))

          answer(
            tags: tags.rows.map { summary(it, usage.fetch(it.id, Blog::Constants::EMPTY_HASH)) },
            count: tag_queries.count_matching(scope, text),
            **Blog::Helpers::Paging.fields(tags),
          )
        end

        def summary(tag, held = Blog::Constants::EMPTY_HASH)
          { id: tag.id, name: tag.name, scope: tag.scope, color: tag.color, count: held.values.sum, by_kind: held }
        end
      end
    end
  end
end
