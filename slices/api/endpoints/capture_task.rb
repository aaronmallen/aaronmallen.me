# frozen_string_literal: true

module API
  module Endpoints
    class CaptureTask < TaskEndpoint
      NEXT = Blog::Types::TaskFilter["next"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          list: {
            type: "string",
            enum: Tasks::LISTS,
            description: "today puts it in today's sprint; next when you leave it out",
          },
          note: { type: "string", description: "what done looks like, in Markdown" },
          sprint_on: { type: "string", description: "a sprint day to schedule it for, as YYYY-MM-DD" },
          tags: { type: "array", items: { type: "string" },
                  description: "tags for the task, #{Helpers::Tags::FORMAT}" },
          title: { type: "string", description: "the task" },
        },
        required: ["title"],
      }.freeze

      include Deps[capture_task: "tasks.operations.capture_task"]

      def handle(title:, list: NEXT, note: nil, sprint_on: nil, tags: nil)
        case capture_task.call({ title:, note:, tags: Helpers::Wording.tag_list(tags) }, filter: list, sprint_on:)
          in Success[_, task, *] then answered(task.id)
          in Failure(:past) | Failure(:invalid) then sprint_past
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
