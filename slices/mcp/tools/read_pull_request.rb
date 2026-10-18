# frozen_string_literal: true

module MCP
  module Tools
    class ReadPullRequest < Base
      description "Read one pull request I authored: its repository, number, title, description, URL, state, " \
                  "the times it was ready for review, merged or closed, and the records linked to it, grouped by " \
                  "kind. The title and description may come from the maintainers of the pull request's " \
                  "repository and come marked untrusted. #{Untrusted::LINKS}"
      endpoint
    end
  end
end
