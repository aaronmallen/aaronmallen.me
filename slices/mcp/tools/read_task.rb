# frozen_string_literal: true

module MCP
  module Tools
    class ReadTask < Base
      description "Read one task: its title, note, status, list or sprint day, tags, links to other tasks both " \
                  "ways, its comments, oldest first, and the other records linked to it, grouped by kind"
      input_schema(API::Endpoints::ReadTask::SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, **input) = hand_over(:read_task, input, server_context)
      end
    end
  end
end
