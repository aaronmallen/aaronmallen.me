# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskTagRules < Base
      description "List the task tag rules by pattern, each with its ID, provider, pattern and tags. A rule gives " \
                  "its private tags to every issue imported from its provider that its pattern matches: a GitHub " \
                  "repo, or a Linear workspace and team"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
