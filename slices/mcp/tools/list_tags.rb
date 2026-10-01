# frozen_string_literal: true

module MCP
  module Tools
    class ListTags < Base
      SCHEMA = {
        additionalProperties: false,
        properties: { page: Paging::PAGE, scope: TAG_SCOPE },
        required: ["scope"],
      }.freeze

      description "List the tags in one scope by name with their colour, how many records carry each, and that " \
                  "count split by kind. Public tags go on posts and projects; private tags go on journal entries " \
                  "and tasks. A tag nothing carries counts zero. #{Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(scope:, server_context:, page: 1)
          usage = tag_usage(server_context).call(scope:)
          requested = page(page, server_context)
          tags = matching_tags(server_context).call(scope:, text: Blog::Constants::EMPTY_STRING, page: requested)

          answer(
            tags: tags.rows.map { summary(it, usage.fetch(it.id, Blog::Constants::EMPTY_HASH)) },
            **Paging.fields(tags),
          )
        end

        def summary(tag, held = Blog::Constants::EMPTY_HASH)
          { id: tag.id, name: tag.name, scope: tag.scope, color: tag.color, count: held.values.sum, by_kind: held }
        end
      end
    end
  end
end
