# frozen_string_literal: true

module MCP
  module Tools
    class ScheduleTask < Base
      description "Schedule one task into the sprint for a day, starting that sprint when it has none yet, " \
                  "or unschedule it back to next. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
