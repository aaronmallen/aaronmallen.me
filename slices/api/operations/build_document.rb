# frozen_string_literal: true

module API
  module Operations
    class BuildDocument
      BODIES = %w[patch post].freeze
      FIELD = /\{(\w+)\}/
      JSON_TYPE = "application/json"
      OPENAPI = "3.1.0"
      RESPONSES = "#/components/responses/"
      SCHEMAS = "#/components/schemas/"
      SERVER = "/api/v1"
      SUCCESS = "the request worked"
      TITLE = "aaronmallen.me API"
      VERSION = "1"

      OPERATIONS = OperationTable::OPERATIONS

      REFUSAL = Helpers::Schema.object(
        {
          error: { type: "string", enum: [*Action::STATUSES.keys.map(&:to_s), Action::NOT_AN_OBJECT.fetch(:error)] },
          message: Helpers::Schema::STRING,
        },
        optional: { errors: { type: "object", additionalProperties: Helpers::Schema.list(Helpers::Schema::STRING) } },
      ).freeze

      UNAUTHORIZED = Helpers::Schema.object(
        { error_description: Helpers::Schema::STRING },
        optional: { error: { type: "string", enum: [Authenticate::INVALID_TOKEN] } },
      ).freeze

      FORBIDDEN = Helpers::Schema.object(
        { error: { type: "string", enum: [Action::INSUFFICIENT_SCOPE] }, error_description: Helpers::Schema::STRING },
      ).freeze

      REFUSALS = {
        "400" => ["BadBody", "the body is not a JSON object", "Refusal"],
        "401" => ["Unauthorized", "no token, or one that is unknown, revoked or expired", "Unauthorized"],
        "403" => ["Forbidden", "the token lacks the scope this operation needs", "Forbidden"],
        "404" => ["NotFound", "no record has that ID", "Refusal"],
        "409" => ["Conflict", "the record changed elsewhere first", "Refusal"],
        "422" => ["Invalid", "the input fails a check", "Refusal"],
        "500" => ["Failed", "the site could not finish the work", "Refusal"],
        "503" => ["Unavailable", "a service the work needs is down or not set up", "Refusal"],
      }.freeze

      REFUSAL_TESTS = {
        "400" => -> { it.body.any? },
        "401" => ->(_row) { true },
        "403" => ->(_row) { true },
        "404" => -> { it.fields.any? || it.finds? },
        "409" => -> { it.endpoint? && it.source.const_defined?(:CONFLICTS) },
        "422" => -> { it.properties.any? },
        "500" => lambda(&:endpoint?),
        "503" => -> { it.endpoint? && it.source::UNAVAILABLE },
      }.freeze

      Descriptor = Data.define(:id, :verb, :path, :status, :source) do
        def body
          return {} unless body?

          schema = { type: "object", additionalProperties: false, properties: rest, required: }.reject do |_, value|
            value == []
          end
          { requestBody: { required: required.any?, content: BuildDocument.json(schema) } }
        end

        def body? = BODIES.include?(verb) && rest.any?

        def endpoint? = source < Endpoint

        def fields = path.scan(FIELD).flatten

        def finds? = endpoint? && source::FINDS

        def properties = source::SCHEMA.fetch(:properties, {})

        def query = verb == "get" ? rest : {}

        def refusal_codes = REFUSAL_TESTS.filter_map { |code, test| code if test.call(self) }

        def to_h(summary:)
          { operationId: id, summary:, parameters:, **body, responses: }
        end

        private

        def parameter(name, place, schema, required:)
          exploded = schema[:type] == "array" ? { style: "form", explode: false } : {}

          { name:, in: place, required:, schema:, **exploded }
        end

        def parameters
          [
            *fields.map { parameter(it, "path", properties.fetch(it.to_sym), required: true) },
            *query.map { |name, schema| parameter(name.to_s, "query", schema, required: required.include?(name.to_s)) },
          ]
        end

        def required = source::SCHEMA.fetch(:required, []) - fields

        def responses
          {
            status.to_s => { description: SUCCESS, content: BuildDocument.json(source::REPLY) },
            **refusal_codes.to_h { [it, { "$ref": "#{RESPONSES}#{REFUSALS.fetch(it).first}" }] },
          }
        end

        def rest = properties.except(*fields.map(&:to_sym))
      end

      include Deps["inflector"]

      def self.json(schema) = { JSON_TYPE => { schema: } }

      def call
        {
          openapi: OPENAPI,
          info: { title: TITLE, version: VERSION },
          servers: [{ url: SERVER }],
          security: [{ token: [] }],
          paths:,
          components:,
        }
      end

      def descriptor(id)
        _, verb, path, status = OPERATIONS.assoc(id)
        Descriptor.new(id:, verb:, path:, status:, source: source(id))
      end

      private

      def components
        {
          schemas: { Refusal: REFUSAL, Unauthorized: UNAUTHORIZED, Forbidden: FORBIDDEN, **serializers },
          responses: REFUSALS.values.to_h { |name, description, schema| [name, refusal(description, schema)] },
          securitySchemes: { token: { type: "http", scheme: "bearer" } },
        }
      end

      def paths
        OPERATIONS.map { descriptor(it.first) }.each_with_object({}) do |row, found|
          found[row.path] = found.fetch(row.path, {}).merge(row.verb => row.to_h(summary: inflector.humanize(row.id)))
        end
      end

      def refusal(description, schema)
        { description:, content: BuildDocument.json({ "$ref": "#{SCHEMAS}#{schema}" }) }
      end

      def serializers
        Serializers.constants.sort.map { Serializers.const_get(it) }.to_h { [it.component, it::SCHEMA] }
      end

      def source(id)
        action = OperationTable::ACTIONS[id]
        return Endpoints.const_get(inflector.camelize(id)) unless action

        Actions.const_get(inflector.camelize(action.tr(".", "/")))
      end
    end
  end
end
