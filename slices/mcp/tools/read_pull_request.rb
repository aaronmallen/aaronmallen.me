# frozen_string_literal: true

module MCP
  module Tools
    class ReadPullRequest < Base
      description "Read one pull request I authored: its repository, number, title, description, URL, state, " \
                  "the times it was ready for review, merged or closed, and the records linked to it, grouped by " \
                  "kind. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
