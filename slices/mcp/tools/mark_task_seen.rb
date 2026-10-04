# frozen_string_literal: true

module MCP
  module Tools
    class MarkTaskSeen < Base
      description "Mark one synced issue seen to clear it from the inbox; it stays in its list. " \
                  "A task with no synced issue is refused"
      input_schema(API::Endpoints::MarkTaskSeen::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:mark_task_seen, input, server_context)
      end
    end
  end
end
