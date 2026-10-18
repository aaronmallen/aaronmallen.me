# frozen_string_literal: true

module MCP
  module Tools
    class ReadSocialPost < Base
      description "Read one social post by ID, sent or not, such as a social hit from search: its status, " \
                  "targets, times, parts in order, each part's photos in order with their key and alt text, " \
                  "each part's length and limit on each network it targets, each account's delivery with its " \
                  "network, link, error and engagement counts, the suggested edits still open and the records " \
                  "linked to it, grouped by kind. #{Untrusted::DELIVERY}. #{Untrusted::SUGGESTED}. " \
                  "#{Untrusted::LINKS}"
      endpoint
    end
  end
end
