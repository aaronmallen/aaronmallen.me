# frozen_string_literal: true

module MCP
  module Tools
    class ReadPullRequest < Base
      description "Read one pull request I authored: its repository, number, title, description, URL, state and " \
                  "the times it was ready for review, merged or closed."
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
