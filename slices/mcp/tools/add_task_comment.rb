# frozen_string_literal: true

module MCP
  module Tools
    class AddTaskComment < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer", description: "the task to comment on" },
          body: { type: "string", description: "the comment, in Markdown" },
        },
        required: %w[id body],
      }.freeze

      description "Add a comment to a task, as the admin's comment form does. It stays on this site and never " \
                  "posts to GitHub or Linear"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, body:, server_context:)
          case add_task_comment(server_context).call(id, { body: })
          in Success(comment) then answer(comment_entry(comment))
          in Failure(:not_found) then no_task(id)
          in Failure[:invalid, errors] then refuse(complaint(errors))
          else unsaved
          end
        end
      end
    end
  end
end
