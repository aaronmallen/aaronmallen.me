# frozen_string_literal: true

module MCP
  module Tools
    class DeleteWorkSession < Base
      description "Delete one of a task's finished work sessions, tracked by mistake. Its length comes " \
                  "off the task's total. The running session stays; pause or complete the task first"
      input_schema(API::Endpoints::DeleteWorkSession::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_work_session, input, server_context)
      end
    end
  end
end
