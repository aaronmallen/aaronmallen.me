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
          project: { type: "string", description: "the key of the project to number the task in, such as POD" },
          recur: Tasks::RECUR,
          sprint_on: { type: "string", description: "a sprint day to schedule it for, as YYYY-MM-DD" },
          tags: { type: "array", items: { type: "string" },
                  description: "tags for the task, #{Helpers::Tags::FORMAT}" },
          title: { type: "string", description: "the task" },
        },
        required: ["title"],
      }.freeze

      include Deps[capture_task: "tasks.operations.capture_task", project_queries: "projects.repos.project_queries"]

      def handle(title:, list: NEXT, note: nil, project: nil, sprint_on: nil, tags: nil, recur: nil)
        fields = { title:, note:, project:, tags: Blog::Types::TagField[tags], recur: Tasks.recur(recur) }

        case capture_task.call(fields, filter: list, sprint_on:)
          in Success[_, task, *] then answered(task.id)
          in Failure(:past) then sprint_past
          in Failure(:invalid) then sprint_unread
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end

      private

      def public_in(fields)
        key = Blog::Types::OptionalText[fields[:project]]&.upcase
        id = key && project_queries.live_id_by_key(key)
        PUBLIC_TASK if id && project_queries.public_boards([id]).any?
      end
    end
  end
end
