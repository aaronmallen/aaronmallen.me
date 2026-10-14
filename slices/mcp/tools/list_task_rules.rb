# frozen_string_literal: true

module MCP
  module Tools
    class ListTaskRules < Base
      description "List the task rules by pattern, each with its ID, provider, pattern, tags and project. A rule " \
                  "gives its private tags to every issue imported from its provider that its pattern matches, a " \
                  "GitHub repo or a Linear workspace and team, and puts the issue in its project"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
