# frozen_string_literal: true

module MCP
  module Tools
    class ReadMemoryFile < Base
      description "Read one memory file: its path, scope, facts and every change to it, oldest first, with the " \
                  "agent and model that made each, or null for the owner. #{Untrusted::MEMORY}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
