# frozen_string_literal: true

module MCP
  module Tools
    class ListShortLinks < Base
      description "List the short links on the share host, newest first or most clicked first with sort clicks, " \
                  "each with its ID, code, link, destination, title, clicks and times. Give filter failing to keep " \
                  "the links whose destination fails the link check, and query to find words in a title, " \
                  "destination or code. list_links lists record links, not these. #{API::Helpers::Paging::USAGE}. " \
                  "#{Untrusted::SHORT_LINKS}"
      endpoint
    end
  end
end
