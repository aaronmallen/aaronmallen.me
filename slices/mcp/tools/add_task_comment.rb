# frozen_string_literal: true

module MCP
  module Tools
    class AddTaskComment < Base
      description "Add a comment to a task, as the admin's comment form does. It stays on this site and never " \
                  "posts to GitHub or Linear"
      input_schema(API::Endpoints::AddTaskComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:add_task_comment, input, server_context)
      end
    end
  end
end
