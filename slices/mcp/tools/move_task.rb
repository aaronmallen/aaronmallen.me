# frozen_string_literal: true

module MCP
  module Tools
    class MoveTask < Base
      description "Move one task to next, someday, external or today's sprint. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::MoveTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:move_task, input, server_context) { Untrusted.task(it) }
      end
    end
  end
end
