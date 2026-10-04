# frozen_string_literal: true

module MCP
  module Tools
    class CaptureTask < Base
      description "Capture a new task, as the admin's Create Task form does. Name a sprint_on day to schedule it " \
                  "into that day's sprint. " \
                  "The note and each comment's body may come from an issue tracker and come marked " \
                  "untrusted. #{Untrusted::WARNING}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
