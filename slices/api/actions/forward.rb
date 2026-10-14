# auto_register: false
# frozen_string_literal: true

module API
  module Actions
    class Forward < Action
      DELETE = Blog::Types::OAuthScope["delete"]
      HEALTH = Blog::Types::OAuthScope["health"]
      MAIL = Blog::Types::OAuthScope["mail"]
      MAIL_ENDPOINTS = %w[
        delete_mail_threads list_mail_threads mark_mail_thread mark_mail_threads_read mark_mail_threads_unread
        read_mail_thread snooze_mail_threads tag_mail_threads untag_mail_threads
      ].freeze
      PARAMS = {
        "array" => Blog::Types::ListParam,
        "integer" => Blog::Types::IntegerParam,
        Helpers::Schema::TASK[:type] => Blog::Types::IntegerParam,
      }.freeze
      PUBLISH = Blog::Types::OAuthScope["publish"]
      SUGGEST = Blog::Types::OAuthScope["suggest"]
      SCOPES = {
        "delete_posts" => DELETE, "delete_tasks" => DELETE, "drop_sprint" => WRITE, "publish_post" => PUBLISH,
        "read_health_days" => HEALTH, "send_social_post" => PUBLISH, "suggest_edits" => SUGGEST,
        "unlink_records" => WRITE, "unlink_task" => WRITE,
        "untag_decision" => WRITE, **MAIL_ENDPOINTS.to_h { [it, MAIL] },
      }.freeze

      include Deps[build_document: "operations.build_document"]

      def self.route(operation) = ->(env) { new(operation:).call(env) }

      def initialize(operation:, **)
        @operation = operation
        @endpoint = Slice["endpoints.#{operation}"]
        super(**)
      end

      def handle(request, response)
        case endpoint.call(input(request, response), scopes: response[:token].scopes)
          in Success(payload) then render_json(response, payload, status: descriptor.status)
          in Failure(Structs::Refusal => refusal)
            render_json(response, refusal.to_h, status: STATUSES.fetch(refusal.error))
        end
      end

      private

      attr_reader :endpoint, :operation

      def body(request, response)
        parsed = request.env.fetch(ACTION_PARSED_BODY, Blog::Constants::EMPTY_HASH)
        return parsed if parsed.is_a?(Hash)

        response.format = :json
        halt BAD_REQUEST, JSON.generate(NOT_AN_OBJECT)
      end

      def descriptor = build_document.descriptor(operation)

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
