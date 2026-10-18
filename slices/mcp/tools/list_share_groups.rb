# frozen_string_literal: true

module MCP
  module Tools
    class ListShareGroups < Base
      description "List the share groups, several files under one link, newest first, each with its ID, code, " \
                  "name, link, page views, zip downloads and files, every file with its own link and downloads"
      endpoint
    end
  end
end
