# frozen_string_literal: true

module MCP
  module Tools
    class UntagTasks < Base
      description "Take one private tag off up to 100 tasks at once. One that is missing changes none"
      input_schema(API::Endpoints::UntagTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:untag_tasks, input, server_context)
      end
    end
  end
end
