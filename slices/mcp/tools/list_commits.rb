# frozen_string_literal: true

module MCP
  module Tools
    class ListCommits < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Blog::Helpers::DayWindow::DAYS,
          repos: {
            type: "array",
            items: { type: "string" },
            description: "repository names, with or without the owner; a commit in any of them comes back",
          },
          to: Blog::Helpers::DayWindow::DAYS,
        },
        required: %w[from to],
      }.freeze

      description "List the commits in a date range, each with its sha, repository, branch, whole message, " \
                  "date, time and lines added and deleted. #{Blog::Helpers::DayWindow::PAGING_NOTE}"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(from:, to:, server_context:, repos: nil)
          case Blog::Helpers::DayWindow.days(from, to)
            in Success[first, last] then listed(first, last, Array(repos), server_context)
            in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, repos, server_context)
          page = Blog::Helpers::DayWindow.page(first, last, day: :commit_date.to_proc) do |from, to, limit|
            dep(:commit_queries, server_context).between(from:, to:, repos:, limit:)
          end
          rows = page.fetch(:rows)
          window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

          answer(window.merge(commits: API::Serializers::Commit.new(rows).serializable_hash))
        end
      end
    end
  end
end
