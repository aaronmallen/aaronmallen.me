# frozen_string_literal: true

module MCP
  module Tools
    class ListSessions < Base
      description "List agent sessions, newest first, each with its agent, model, client, repo, branch, tasks, the " \
                  "memory files it loaded, the memory changes and artifact versions it wrote, and when it started, " \
                  "was last seen and ended, or null while it runs. #{API::Helpers::Paging::USAGE}. " \
                  "#{Untrusted::SESSIONS}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
