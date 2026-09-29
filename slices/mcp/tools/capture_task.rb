# frozen_string_literal: true

module MCP
  module Tools
    class CaptureTask < TaskTool
      NEXT = Blog::Types::TaskFilter["next"]
      NO_TAGS = Dry::Core::Constants::EMPTY_ARRAY

      SCHEMA = {
        additionalProperties: false,
        properties: {
          list: {
            type: "string",
            enum: LISTS,
            description: "today puts it in today's sprint; next when you leave it out",
          },
          sprint_on: { type: "string", description: "a sprint day to schedule it for, as YYYY-MM-DD" },
          tags: { type: "array", items: { type: "string" }, description: "tags for the task, lowercase words" },
          title: { type: "string", description: "the task" },
        },
        required: ["title"],
      }.freeze

      description "Capture a new task, as the admin's Create Task form does. Name a sprint_on day to schedule it " \
                  "into that day's sprint"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(title:, server_context:, list: NEXT, sprint_on: nil, tags: NO_TAGS)
          fields = { title:, tags: tag_text(tags) }

          case capture_task(server_context).call(fields, filter: list, sprint_on:)
          in Success[_, task, *] then task_answer(task.id, server_context)
          in Failure(:past) | Failure(:invalid) then sprint_past
          in Failure[:invalid, errors] then refuse(complaint(errors))
          else unsaved
          end
        end
      end
    end
  end
end
