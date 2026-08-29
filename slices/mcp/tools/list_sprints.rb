# frozen_string_literal: true

module MCP
  module Tools
    class ListSprints < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
      }.freeze

      description "List sprints by day, oldest first, each with how many tasks it carried in from the day " \
                  "before. Leave from and to both out for today's sprint and every one planned after it; " \
                  "leave one out to leave that end open"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, from: nil, to: nil)
          case window(from || opening(to), to)
          in Success[first, last] then answer(sprints: listed(first, last, server_context).map { sprint_entry(it) })
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, server_context) = sprints_between(server_context).call(from: first, to: last)

        def opening(to) = to ? nil : Blog::TimeZone.today.iso8601
      end
    end
  end
end
