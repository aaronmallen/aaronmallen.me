# frozen_string_literal: true

module API
  module Helpers
    module Schema
      BOOLEAN = { type: "boolean" }.freeze
      CREDITS = {
        agent: { type: "string", description: "an agent, such as claude-code; only the tasks it worked on" },
        contributor: {
          type: "string",
          enum: Blog::Types::ContributorKind.values,
          description: "owner or agent; owner also keeps every task that lists no contributors",
        },
        model: { type: "string", description: "a model, such as claude-opus-5-5; only the tasks it worked on" },
      }.freeze
      DAY = { type: "string", format: "date" }.freeze
      ID = { type: "integer", minimum: 1, maximum: Blog::Constants::INTEGER_MAX }.freeze
      INTEGER = { type: "integer" }.freeze
      STAMP = { type: "string", format: "date-time" }.freeze
      STRING = { type: "string" }.freeze
      TAGS = { type: "array", items: STRING }.freeze
      TASK = {
        type: %w[integer string],
        minimum: 1,
        maximum: Blog::Constants::INTEGER_MAX,
        pattern: "^([A-Za-z][A-Za-z0-9]{1,5}-)?[1-9][0-9]{0,8}$",
        description: "a task's internal ID as a number, or its label as a string: KEY-n, or n with no project",
      }.freeze

      module_function

      def bulk(noun, item = ID)
        { additionalProperties: false, properties: { ids: ids(noun, item) }, required: ["ids"] }.freeze
      end

      def by_id(id = ID) = { additionalProperties: false, properties: { id: }, required: ["id"] }.freeze

      def ids(noun, item = ID)
        most = Blog::Contract::MAX_IDS

        {
          type: "array",
          items: item,
          minItems: 1,
          maxItems: most,
          description: "the #{noun} to change, #{most} at most; one that fails changes none".freeze,
        }.freeze
      end

      def list(items) = { type: "array", items: }

      def names(properties) = properties.keys.map(&:to_s)

      def nullable(schema)
        widened = schema.merge(type: [*schema.fetch(:type), "null"])
        schema.key?(:enum) ? widened.merge(enum: [*schema.fetch(:enum), nil]) : widened
      end

      def object(properties, optional: {})
        required = names(properties)

        { type: "object", additionalProperties: false, properties: properties.merge(optional), required: }
      end

      def paged(properties, more: { next_page: INTEGER })
        object(properties.merge(partial: BOOLEAN), optional: more)
      end

      def task?(schema) = (schema[:items] || schema)[:pattern] == TASK[:pattern]

      def widen(schema, **properties)
        required = schema.fetch(:required) + names(properties)

        schema.merge(properties: schema.fetch(:properties).merge(properties), required:)
      end
    end
  end
end
