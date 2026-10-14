# frozen_string_literal: true

module MCP
  module Tools
    class ReadTask < Base
      description "Read one task: its title, note, status, list or sprint day, tags, links to other tasks both " \
                  "ways, the issue it syncs from (null for a local task), its created, updated and completed " \
                  "times, its comments, oldest first, the other records linked to it, grouped by kind, and its " \
                  "timeline: comments, work sessions with their IDs, moves, tag changes and status changes, " \
                  "oldest first. #{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
