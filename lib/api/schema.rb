# frozen_string_literal: true

module API
  module Schema
    BOOLEAN = { type: "boolean" }.freeze
    DAY = { type: "string", format: "date" }.freeze
    INTEGER = { type: "integer" }.freeze
    STAMP = { type: "string", format: "date-time" }.freeze
    STRING = { type: "string" }.freeze
    TAGS = { type: "array", items: STRING }.freeze

    module_function

    def list(items) = { type: "array", items: }

    def names(properties) = properties.keys.map(&:to_s)

    def nullable(schema)
      widened = schema.merge(type: [schema.fetch(:type), "null"])
      schema.key?(:enum) ? widened.merge(enum: [*schema.fetch(:enum), nil]) : widened
    end

    def object(properties, optional: {})
      required = names(properties)

      { type: "object", additionalProperties: false, properties: properties.merge(optional), required: }
    end

    def widen(schema, **properties)
      required = schema.fetch(:required) + names(properties)

      schema.merge(properties: schema.fetch(:properties).merge(properties), required:)
    end
  end
end
