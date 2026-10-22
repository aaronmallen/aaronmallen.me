# frozen_string_literal: true

module MCP
  module Tools
    class RemoveShareGroupFile < Base
      description "Delete one file from a share group, by the group's ID and the file's, with its stored file. Its " \
                  "link stops working, and the group goes too when it held only that file. This cannot be undone"
      endpoint
    end
  end
end
