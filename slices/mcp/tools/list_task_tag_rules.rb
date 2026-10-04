# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskTagRules < Base
      description "List the task tag rules by pattern, each with its ID, pattern and tags. A rule gives its private " \
                  "tags to every issue imported from a repo its pattern matches"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
