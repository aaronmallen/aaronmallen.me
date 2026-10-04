# frozen_string_literal: true

module MCP
  module Tools
    class ListDecisions < Base
      description "List decisions, newest first, each with its problem, status, options and tags. Narrow them by " \
                  "status, by one private tag, or both. count gives the decisions on this page. #{Blog::Paging::USAGE}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
