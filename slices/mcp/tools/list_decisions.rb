# frozen_string_literal: true

module MCP
  module Tools
    class ListDecisions < Base
      description "List decisions, newest first, each with its problem, status, options and tags. Narrow them by " \
                  "status, by one private tag, by words in the title or problem, or any of these. count gives the " \
                  "decisions on this page, and counts how many with the same words and tag sit in each status, " \
                  "whatever status asks for. #{Blog::Helpers::Paging::USAGE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
