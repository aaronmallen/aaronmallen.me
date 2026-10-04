# frozen_string_literal: true

module MCP
  module Tools
    class ReadCommit < Base
      description "Read one commit: its sha, repository, branch, whole message, date, time, lines added and " \
                  "deleted and the records linked to it, grouped by kind"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
