# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTask < Base
      description "Mark one open or started task done, stamped with the time now. It ends the running work " \
                  "session; hours and minutes, when given, replace the total time worked. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      input_schema(API::Endpoints::CompleteTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:complete_task, input, server_context) { Untrusted.task(it) }
      end
    end
  end
end
