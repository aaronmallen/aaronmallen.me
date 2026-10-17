# frozen_string_literal: true

module MCP
  module Tools
    class ResumeTaskSeries < Base
      description "Resume one paused recurring task series by its ID. If its current copy is already closed, the " \
                  "next copy appears at once on the next cadence day after today, or after its sprint day when " \
                  "that day is still ahead; if it is open, the next copy follows when it closes"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
