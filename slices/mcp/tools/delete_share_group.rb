# frozen_string_literal: true

module MCP
  module Tools
    class DeleteShareGroup < Base
      description "Delete a share group by ID with every file in it and their stored files. Its link and each " \
                  "file's link stop working. This cannot be undone"
      endpoint
    end
  end
end
