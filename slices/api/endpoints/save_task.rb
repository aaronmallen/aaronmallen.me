# frozen_string_literal: true

module API
  module Endpoints
    class SaveTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          list: { type: "string", enum: Tasks::LISTS, description: "moves the task to this list or today's sprint" },
          note: { type: "string", description: "what done looks like" },
          sprint_on: {
            type: "string",
            description: "a sprint day as YYYY-MM-DD to schedule it for, or an empty string to send it back to next",
          },
          tags: { type: "array", items: { type: "string" }, description: "the whole set of tags, lowercase words" },
          title: { type: "string" },
        },
        required: ["id"],
      }.freeze

      include Deps[save_task: "tasks.operations.save_task"]

      def handle(id:, **fields)
        task = task_by_id.call(id)
        return not_found(Tasks.missing(id)) if task.nil?

        case save_task.call(id, form(task, fields))
        in Failure[:invalid, errors] then rejected(errors)
        in result then placed(result, id)
        end
      end

      private

      def form(task, fields)
        {
          list: fields[:list],
          note: fields.fetch(:note, task.note),
          sprint_on: fields[:sprint_on],
          tags: Wording.tag_list(fields.fetch(:tags, task.tags.map(&:name))),
          title: fields.fetch(:title, task.title),
        }
      end
    end
  end
end
