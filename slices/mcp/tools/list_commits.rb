# frozen_string_literal: true

module MCP
  module Tools
    class ListCommits < Base
      description "List the commits in a date range, each with its sha, repository, branch, whole message, " \
                  "date, time and lines added and deleted. #{API::Helpers::DayWindow::PAGING_NOTE}"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
