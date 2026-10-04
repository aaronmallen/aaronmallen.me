# frozen_string_literal: true

require "dry/monads"
require "json"

module MCP
  module Tools
    class Base < Tool
      TAG_SCOPE = {
        type: "string",
        enum: Blog::Types::TagScope.values,
        description: "public holds the tags on posts and projects; private holds those on journal entries and tasks",
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
            hand_over(endpoint_key, input, server_context) { answered(it) }
          end
        end

        def scope(value) = @scope_value = value

        private

        def answer(payload) = Tool::Response.new([{ type: TEXT, text: JSON.generate(payload) }])

        def answered(payload) = Untrusted.task(payload)

        def dep(name, server_context) = server_context.fetch(name)

        def every_tag(server_context)
          Blog::Types::TagScope.values.flat_map { dep(:all_tags, server_context).call(scope: it) }.sort_by(&:name)
        end

        def every_tag_usage(server_context)
          Blog::Types::TagScope.values.map { dep(:tag_usage, server_context).call(scope: it) }.reduce(:merge)
        end

        def hand_over(endpoint, input, server_context, &shape)
          case dep(endpoint, server_context).call(input)
          in Success(payload) then answer(shape ? yield(payload) : payload)
          in Failure(refusal) then refuse(refusal.message)
          end
        end

        def page(number, server_context) = Blog::Page.new(number:, size: dep(:page_size, server_context))

        def record_links(kind, id, server_context)
          dep(:list_links, server_context).call(kind:, id:).value!.fetch(:links)
        end

        def refuse(message) = Tool::Response.new([{ type: TEXT, text: message }], error: true)

        def refuse_long_range = refuse(Blog::DayWindow::TOO_LONG)

        def too_long?(first, last) = Blog::DayWindow.too_long?(first, last)
      end
    end
  end
end
