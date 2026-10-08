# frozen_string_literal: true

module MCP
  module Tools
    class ReadDecision < Base
      description "Read one decision: its title, problem, status, tags, when it was opened and last changed, its " \
                  "options, the option it was resolved with and why, its comments, oldest first, the records " \
                  "linked to it, grouped by kind, tasks among them, and its timeline: comments, options added or " \
                  "edited, edits, resolutions, drops and reopenings with their reasons, oldest first. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
