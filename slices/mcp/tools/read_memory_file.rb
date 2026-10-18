# frozen_string_literal: true

module MCP
  module Tools
    class ReadMemoryFile < Base
      description "Read one memory file: its path, scope, facts and its history of changes, newest first, with " \
                  "the agent and model that made each, or null for the owner. Facts come whole; history comes a " \
                  "page at a time. When more remains, partial comes back true and next_page holds the page to " \
                  "send for older changes. #{Untrusted::MEMORY}"
      endpoint scope: Blog::Types::OAuthScope["agents"]
    end
  end
end
