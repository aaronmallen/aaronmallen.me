# frozen_string_literal: true

module MCP
  module Tools
    class ScheduleTask < Base
      description "Schedule one task into the sprint for a day, starting that sprint when it has none yet, " \
                  "or unschedule it back to next"
      input_schema(API::Endpoints::ScheduleTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:schedule_task, input, server_context)
      end
    end
  end
end
