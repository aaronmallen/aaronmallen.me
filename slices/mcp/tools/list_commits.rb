# frozen_string_literal: true

module MCP
  module Tools
    class ListCommits < Base
      TIME_FORMAT = "%H:%M"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Blog::DayWindow::DAYS,
          repos: {
            type: "array",
            items: { type: "string" },
            description: "repository names, with or without the owner; a commit in any of them comes back",
          },
          to: Blog::DayWindow::DAYS,
        },
        required: %w[from to],
      }.freeze

      description "List the commits in a date range, each with its sha, repository, branch, whole message, " \
                  "date, time and lines added and deleted. #{Blog::DayWindow::PAGING_NOTE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, repos: nil)
          case Blog::DayWindow.days(from, to)
          in Success[first, last] then listed(first, last, Array(repos), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def fields(commit)
          {
            id: commit.id,
            sha: commit.sha,
            repo: commit.repo,
            branch: commit.branch,
            message: commit.message,
            date: commit.commit_date.iso8601,
            time: commit.commit_time.strftime(TIME_FORMAT),
            additions: commit.additions,
            deletions: commit.deletions,
          }
        end

        def listed(first, last, repos, server_context)
          page = Blog::DayWindow.page(first, last, day: :commit_date.to_proc) do |from, to, limit|
            commits_between(server_context).call(from:, to:, repos:, limit:)
          end
          rows = page.fetch(:rows)
          window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

          answer(window.merge(commits: rows.map { fields(it) }))
        end
      end
    end
  end
end
