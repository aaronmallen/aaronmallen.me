# frozen_string_literal: true

module API
  module Endpoints
    class SaveTask < TaskEndpoint
      RECUR = "#{Tasks::RECUR.fetch(:description)}; a new cadence replaces the old one and keeps a paused series " \
              "paused; null stops it".freeze
      SHOWS_TASKS = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::TASK,
          contributors: Tasks::CONTRIBUTORS,
          list: { type: "string", enum: Tasks::LISTS, description: "moves the task to this list or today's sprint" },
          note: { type: "string", description: "what done looks like" },
          recur: Helpers::Schema.nullable(Tasks::RECUR).merge(description: RECUR),
          sprint_on: {
            type: "string",
            description: "a sprint day as YYYY-MM-DD to schedule it for, or an empty string to send it back to next",
          },
          tags: { type: "array", items: { type: "string" },
                  description: "the whole set of tags, #{Helpers::Tags::FORMAT}" },
          title: { type: "string" },
        },
        required: ["id"],
      }.freeze

      include Deps[save_task: "tasks.operations.save_task"]

      def handle(id:, **fields)
        task = task_queries.detailed(id)
        return missing("task", id) if task.nil?

        case save_task.call(id, form(task, fields))
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          in Failure(:imported) then invalid(recur: [Tasks::IMPORTED])
          in result then placed(result, id)
        end
      end

      private

      def form(task, fields)
        {
          list: fields[:list],
          note: fields.fetch(:note, task.note),
          sprint_on: fields[:sprint_on],
          tags: fields.fetch(:tags) { task.tags.map(&:name) },
          title: fields.fetch(:title, task.title),
          **fields.slice(:contributors),
          **({ recur: Tasks.recur(fields[:recur]) } if fields.key?(:recur)),
        }
      end
    end
  end
end
