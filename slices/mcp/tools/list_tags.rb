# frozen_string_literal: true

module MCP
  module Tools
    class ListTags < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "List every tag by name with its colour, how many records carry it, and that count split " \
                  "by kind: posts, projects, journal entries and tasks. A tag nothing carries counts zero"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          usage = every_tag_usage(server_context)
          tags = every_tag(server_context)

          answer(tags: tags.map { summary(it, usage.fetch(it.id, Dry::Core::Constants::EMPTY_HASH)) })
        end

        def summary(tag, held = Dry::Core::Constants::EMPTY_HASH)
          { id: tag.id, name: tag.name, color: tag.color, count: held.values.sum, by_kind: held }
        end
      end
    end
  end
end
