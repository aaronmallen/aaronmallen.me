# frozen_string_literal: true

module MCP
  module Tools
    class ListSprints < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the window, as YYYY-MM-DD" },
          page: Paging::PAGE,
          to: { type: "string", description: "the last day of the window, as YYYY-MM-DD" },
        },
      }.freeze

      description "List sprints by day, oldest first, each with how many tasks it carried in from the day " \
                  "before. Leave from and to both out for today's sprint and every one planned after it; " \
                  "leave one out to leave that end open. #{Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, from: nil, to: nil, page: 1)
          case window(from || opening(to), to)
          in Success[first, last] then listed(first, last, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, page, server_context)
          found = sprints_between(server_context).call(from: first, to: last, page:)

          answer(sprints: found.rows.map { sprint_entry(it) }, **Paging.fields(found))
        end

        def opening(to) = to ? nil : Blog::TimeZone.today.iso8601
      end
    end
  end
end
