# frozen_string_literal: true

module MCP
  module Tools
    class ListPullRequests < Base
      SCHEMA = {
        additionalProperties: false,
        properties: { from: Blog::Helpers::DayWindow::DAYS, to: Blog::Helpers::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      description "List the pull requests I authored that last moved in a date range, each with its repository, " \
                  "number, title, description, URL, state and the times it was ready for review, merged or " \
                  "closed. A pull request falls on the day it merged or closed, else the day it was ready, else, " \
                  "for a draft, the day it was imported. #{Blog::Helpers::DayWindow::PAGING_NOTE}"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      DAY = ->(pull_request) { Blog::TimeZone.today(pull_request.moved_at) }

      class << self
        def call(from:, to:, server_context:)
          case Blog::Helpers::DayWindow.days(from, to)
            in Success[first, last] then listed(first, last, server_context)
            in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, server_context)
          page = Blog::Helpers::DayWindow.page(first, last, day: DAY) do |from, to, limit|
            dep(:pull_request_queries, server_context).between(from:, to:, limit:)
          end
          rows = page.fetch(:rows).map { API::Serializers::PullRequest.new(it).serializable_hash }
          window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

          answer(window.merge(pull_requests: rows))
        end
      end
    end
  end
end
