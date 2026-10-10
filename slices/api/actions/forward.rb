# auto_register: false
# frozen_string_literal: true

module API
  module Actions
    class Forward < Action
      DELETE = Blog::Types::OAuthScope["delete"]
      PARAMS = { "array" => Blog::Types::ListParam, "integer" => Blog::Types::IntegerParam }.freeze
      PUBLISH = Blog::Types::OAuthScope["publish"]
      SCOPES = {
        "delete_messages" => DELETE, "delete_posts" => DELETE, "delete_tasks" => DELETE,
        "drop_sprint" => WRITE, "publish_post" => PUBLISH, "send_social_post" => PUBLISH,
        "unlink_records" => WRITE, "unlink_task" => WRITE, "untag_decision" => WRITE,
      }.freeze

      def self.route(operation) = ->(env) { new(operation:).call(env) }

      def initialize(operation:, **)
        @descriptor = Operations::BuildDocument.descriptor(operation)
        @endpoint = Slice["endpoints.#{operation}"]
        super(**)
      end

      def handle(request, response)
        case endpoint.call(input(request, response))
          in Success(payload) then render_json(response, payload, status: descriptor.status)
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
        halt BAD_REQUEST, JSON.generate(NOT_AN_OBJECT)
      end

      def input(request, response)
        found = names.filter_map { |name| request.params[name]&.then { [name.to_s, param(name, it)] } }.to_h

        descriptor.body? ? body(request, response).merge(found) : found
      end

      def names = [*descriptor.fields.map(&:to_sym), *descriptor.query.keys]

      def param(name, value) = PARAMS.fetch(descriptor.properties.fetch(name)[:type], Blog::Types::Any)[value]

      def required_scope(request) = SCOPES.fetch(descriptor.id) { super }
    end
  end
end
