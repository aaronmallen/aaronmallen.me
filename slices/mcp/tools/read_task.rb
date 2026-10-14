# frozen_string_literal: true

module MCP
  module Tools
    class ReadTask < Base
      description "Read one task: its title, note, status, list or sprint day, tags, links to other tasks both " \
                  "ways, its cadence in recur (null when it does not recur), the issue it syncs from (null for a " \
                  "local task), its created, updated and completed times, its comments, oldest first, the other " \
                  "records linked to it, grouped by kind, and its timeline: comments, work sessions with their IDs, " \
                  "moves, tag changes, status changes and, for a recurring copy, when its series made it, oldest " \
                  "first. #{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
