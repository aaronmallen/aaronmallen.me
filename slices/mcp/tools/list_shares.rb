# frozen_string_literal: true

module MCP
  module Tools
    class ListShares < Base
      description "List the files shared one to a link, newest first, each with its ID, code, link, file name, " \
                  "media type, size, alt text and downloads. Give filter to keep images or other files, and query " \
                  "to find words in a name, type or code"
      endpoint
    end
  end
end
