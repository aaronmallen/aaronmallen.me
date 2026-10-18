# frozen_string_literal: true

module MCP
  module Tools
    class ArchiveProject < Base
      description "Archive one project as of today, which takes it off /projects. " \
                  "An archived project, or one whose start month has not come yet, stays as it is"
      endpoint
    end
  end
end
