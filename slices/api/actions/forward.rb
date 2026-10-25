# auto_register: false
# frozen_string_literal: true

module API
  module Actions
    class Forward < Action
      PARAMS = {
        "array" => Blog::Types::ListParam,
        "boolean" => Blog::Types::BooleanParam,
        "integer" => Blog::Types::IntegerParam,
        Helpers::Schema::TASK[:type] => Blog::Types::IntegerParam,
      }.freeze

      include Deps[build_document: "operations.build_document"]

      def self.route(operation) = ->(env) { new(operation:).call(env) }

      def initialize(operation:, build_document:, **)
        @endpoint = Slice["endpoints.#{operation}"]
        @descriptor = build_document.descriptor(operation)
        super(build_document:, **)
      end

      def handle(request, response)
        case endpoint.call(input(request, response), scopes: response[:token].scopes)
          in Success(payload) then render_json(response, payload, status: descriptor.status)
          in Failure(Structs::Refusal[error: :unscoped, errors: { scope: }]) then insufficient(response, scope)
          in Failure(Structs::Refusal[error: :undeleted, message:])
            insufficient(response, OperationTable::DELETE, message)
          in Failure(Structs::Refusal[error: :unpublished, message:])
            insufficient(response, OperationTable::PUBLISH, message)
          in Failure(Structs::Refusal => refusal)
            render_json(response, refusal.to_h, status: STATUSES.fetch(refusal.error))
        end
      end

      private

      attr_reader :descriptor, :endpoint

      def body(request, response)
        parsed = request.env.fetch(ACTION_PARSED_BODY, Blog::Constants::EMPTY_HASH)
        return parsed if parsed.is_a?(Hash)

        response.format = :json
        halt :bad_request, JSON.generate(NOT_AN_OBJECT)
      end

      def input(request, response)
        route = request.env.fetch(ROUTER_PARAMS, Blog::Constants::EMPTY_HASH)
        found = names.filter_map { |name| route[name]&.then { [name.to_s, param(name, it)] } }.to_h

        descriptor.body? ? body(request, response).merge(found) : found
      end

      def names = [*descriptor.fields.map(&:to_sym), *descriptor.query.keys]

      def param(name, value) = PARAMS.fetch(descriptor.properties.fetch(name)[:type], Blog::Types::Any)[value]

      def required_scope = OperationTable::SCOPES.fetch(descriptor.id)
    end
  end
end
