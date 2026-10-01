# frozen_string_literal: true

module MCP
  module Tools
    class LinkTasks < Base
      description "Link one task to another. A pair takes one link, whichever way it runs"
      input_schema(API::Endpoints::LinkTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:link_tasks, input, server_context)
      end
    end
  end
end
