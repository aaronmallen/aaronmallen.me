# frozen_string_literal: true

module MCP
  module Tools
    class ReadSocialPost < Base
      description "Read one social post by ID, sent or not, such as a social hit from search: its status, " \
                  "targets, times, parts in order, each part's length and limit on each network it targets, " \
                  "each network's delivery with its link, error and engagement counts, the suggested edits " \
                  "still open and the records linked to it, grouped by kind. #{Untrusted::LINKS}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
