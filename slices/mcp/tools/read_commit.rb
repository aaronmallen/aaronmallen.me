# frozen_string_literal: true

module MCP
  module Tools
    class ReadCommit < Base
      description "Read one commit: its sha, repository, branch, whole message, date, time, lines added and " \
                  "deleted and the records linked to it, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
