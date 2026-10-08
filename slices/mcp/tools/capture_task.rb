# frozen_string_literal: true

module MCP
  module Tools
    class CaptureTask < Base
      description "Capture a new task, as the admin's Create Task form does. Name a sprint_on day to schedule it " \
                  "into that day's sprint. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
