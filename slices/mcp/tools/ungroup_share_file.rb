# frozen_string_literal: true

module MCP
  module Tools
    class UngroupShareFile < Base
      description "Pull a file out of a share group, by the group's ID and the file's, and get it back as a single " \
                  "share with its new code and link. Its link under the group stops working"
      endpoint
    end
  end
end
