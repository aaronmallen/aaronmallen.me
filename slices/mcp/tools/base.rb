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
        attr_reader :endpoint_key

        def described(values) = format(description_value, values)

        def endpoint
          @endpoint_key = name_value.to_sym
          input_schema(API::Endpoints.const_get(name.split("::").last, false)::SCHEMA)
          operations(endpoint_key)
          define_singleton_method(:call) do |server_context:, **input|
            hand_over(endpoint_key, input, server_context)
          end
        end

        def operations(*ids) = @operations = ids

        def scope_value = @operations.flat_map { API::OperationTable::SCOPES.fetch(it.to_s) }.uniq

        private

        def answer(payload) = Tool::Response.new([{ type: TEXT, text: JSON.generate(payload) }])

        def hand_over(endpoint, input, server_context)
          case handed(endpoint, input, server_context)
            in Success(payload) then reply(synced(payload, server_context), server_context)
            in Failure(refusal) then refuse(refusal.message)
          end
        end

        def handed(endpoint, input, server_context)
          API::Helpers::Untrusted.marking do
            server_context.fetch(endpoint).call(input, scopes: server_context.fetch(:scopes))
          end
        end

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def reply(payload, _server_context) = answer(payload)

        def synced(payload, server_context)
          Untrusted.synced(payload) { server_context.fetch(:task_source_queries).synced_task_ids(it) }
        end
      end
    end
  end
end
