# frozen_string_literal: true

module MCP
  module Tools
    class DeleteWorkSession < Base
      description "Delete one of a task's finished work sessions, tracked by mistake. Its length comes " \
                  "off the task's total. The running session stays; pause or complete the task first"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
