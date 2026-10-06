# frozen_string_literal: true

require "dry/monads"
require "json"

module MCP
  module Tools
    class Base < Tool
      PRIVATE_KINDS = "journal entries, tasks, decisions and task tag rules"
      TAG_KINDS = "Public tags go on posts and projects; private tags go on #{PRIVATE_KINDS}".freeze
      TAG_SCOPE = {
        type: "string",
        enum: Blog::Types::TagScope.values,
        description: "public holds the tags on posts and projects; private holds those on #{PRIVATE_KINDS}",
      }.freeze
      TEXT = "text"

      extend Dry::Monads[:result]

      class << self
        attr_reader :endpoint_key, :scope_value

        def endpoint(scope:)
          @endpoint_key = name_value.to_sym
          input_schema(API::Endpoints.const_get(name.split("::").last, false)::SCHEMA)
          scope(scope)
          define_singleton_method(:call) do |server_context:, **input|
            hand_over(endpoint_key, input, server_context) { synced(answered(it), server_context) }
          end
        end

        def scope(value) = @scope_value = value

        private

        def answer(payload) = Tool::Response.new([{ type: TEXT, text: JSON.generate(payload) }])

        def answered(payload) = Untrusted.task(payload)

        def dep(name, server_context) = server_context.fetch(name)

        def hand_over(endpoint, input, server_context, &shape)
          case dep(endpoint, server_context).call(input)
          in Success(payload) then answer(shape ? yield(payload) : payload)
          in Failure(refusal) then refuse(refusal.message)
          end
        end

        def page(number, server_context) = Blog::Page.new(number:, size: dep(:page_size, server_context))

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def synced(payload, server_context)
          Untrusted.synced(payload) { dep(:synced_task_ids, server_context).call(it) }
        end

        def too_long?(first, last) = Blog::DayWindow.too_long?(first, last)
      end
    end
  end
end
