# frozen_string_literal: true

module MCP
  module Tools
    class ListNoteFolders < Base
      description "List every note folder by name, with its description and the folder it sits " \
                  "in, null at the top level"
      endpoint
    end
  end
end
