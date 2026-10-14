# frozen_string_literal: true

require "dry/monads"
require "json"

module MCP
  module Tools
    class Base < Tool
      TAG_KINDS = "Public tags go on posts and projects; private tags go on " \
                  "#{API::Endpoints::TagEndpoint::PRIVATE_KINDS}".freeze
      TEXT = "text"

      extend Dry::Monads[:result]

      class << self
        attr_reader :endpoint_key, :scope_value

        def endpoint(scope:)
          @endpoint_key = name_value.to_sym
          input_schema(API::Endpoints.const_get(name.split("::").last, false)::SCHEMA)
          scope(scope)
          define_singleton_method(:call) do |server_context:, **input|
            hand_over(endpoint_key, input, server_context) { reply(it, server_context) }
          end
        end

        def scope(value) = @scope_value = value

        private

        def answer(payload) = Tool::Response.new([{ type: TEXT, text: JSON.generate(payload) }])

        def answered(payload) = Untrusted.shaped(payload)

        def hand_over(endpoint, input, server_context)
          case server_context.fetch(endpoint).call(input, scopes: server_context.fetch(:scopes))
            in Success(payload) then block_given? ? yield(payload) : answer(payload)
            in Failure(refusal) then refuse(refusal.message)
          end
        end

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def reply(payload, server_context) = answer(synced(answered(payload), server_context))

        def synced(payload, server_context)
          Untrusted.synced(payload) { server_context.fetch(:task_source_queries).synced_task_ids(it) }
        end
      end
    end
  end
end
