# frozen_string_literal: true

module MCP
  module Tools
    class SaveTask < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer" },
          list: { type: "string", enum: LISTS, description: "moves the task to this list or today's sprint" },
          note: { type: "string", description: "what done looks like" },
          sprint_on: {
            type: "string",
            description: "a sprint day as YYYY-MM-DD to schedule it for, or an empty string to send it back to next",
          },
          tags: { type: "array", items: { type: "string" }, description: "the whole set of tags, lowercase words" },
          task_type_id: { type: %w[integer null], description: "a task type ID, or null for no type" },
          title: { type: "string" },
        },
        required: ["id"],
      }.freeze

      description "Edit one task, as the admin's task editor does. A field you leave out keeps what it has; " \
                  "tags replace the whole set"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:, **fields)
          task = task_by_id(server_context).call(id)
          return no_task(id) if task.nil?

          case save_task(server_context).call(id, form(task, fields))
          in Success(*) then task_answer(id, server_context)
          in Failure(:past) | Failure(:invalid) then sprint_past
          in Failure(:not_found) then no_task(id)
          in Failure[:invalid, errors] then refuse(complaint(errors))
          else unsaved
          end
        end

        private

        def form(task, fields)
          {
            list: fields[:list],
            note: fields.fetch(:note, task.note),
            sprint_on: fields[:sprint_on],
            tags: tag_text(fields.fetch(:tags, task.tags.map(&:name))),
            task_type_id: fields.fetch(:task_type_id, task.task_type_id)&.to_s,
            title: fields.fetch(:title, task.title),
          }
        end
      end
    end
  end
end
