# frozen_string_literal: true

module MCP
  module Tools
    class TagTasks < Base
      description "Add one private tag to up to 100 tasks at once. One that is missing tags none"
      input_schema(API::Endpoints::TagTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:tag_tasks, input, server_context)
      end
    end
  end
end
