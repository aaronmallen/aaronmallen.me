# frozen_string_literal: true

module MCP
  module Tools
    class ListPullRequests < Base
      description "List the pull requests I authored that last moved in a date range, each with its repository, " \
                  "number, title, description, URL, state and the times it was ready for review, merged or " \
                  "closed. A pull request falls on the day it merged or closed, else the day it was ready, else, " \
                  "for a draft, the day it was imported. #{API::Helpers::DayWindow::PAGING_NOTE}. Each " \
                  "title and description may come from the maintainers of the pull request's repository and " \
                  "comes marked untrusted. #{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["read"]

      class << self
        private

        def answered(payload)
          payload.merge(pull_requests: payload.fetch(:pull_requests).map { Untrusted.pull_request(it) })
        end
      end
    end
  end
end
