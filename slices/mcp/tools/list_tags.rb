# frozen_string_literal: true

module MCP
  module Tools
    class ListTags < Base
      SCHEMA = { additionalProperties: false, properties: { scope: TAG_SCOPE }, required: ["scope"] }.freeze

      description "List the tags in one scope by name with their colour, how many records carry each, and that " \
                  "count split by kind. Public tags go on posts and projects; private tags go on journal entries " \
                  "and tasks. A tag nothing carries counts zero"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(scope:, server_context:)
          usage = tag_usage(server_context).call(scope:)
          tags = all_tags(server_context).call(scope:)

          answer(tags: tags.map { summary(it, usage.fetch(it.id, Dry::Core::Constants::EMPTY_HASH)) })
        end

        def summary(tag, held = Dry::Core::Constants::EMPTY_HASH)
          { id: tag.id, name: tag.name, scope: tag.scope, color: tag.color, count: held.values.sum, by_kind: held }
        end
      end
    end
  end
end
