# frozen_string_literal: true

module API
  module Endpoints
    class ListCommits < Endpoint
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

      REPLY = Helpers::Schema.paged(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          count: Helpers::Schema::INTEGER,
          commits: Helpers::Schema.list(Serializers::Commit.reference),
        },
        more: { continue_to: Helpers::Schema::DAY },
      ).freeze

      include Deps[commit_queries: "record.repos.commit_queries"]

      def handle(from:, to:, repos: nil)
        case Blog::Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last, Array(repos)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, repos)
        page = Blog::Helpers::DayWindow.page(first, last, day: :commit_date.to_proc) do |from, to, limit|
          commit_queries.between(from:, to:, repos:, limit:)
        end
        rows = page.fetch(:rows)
        window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

        window.merge(commits: serialized(Serializers::Commit, rows))
      end
    end
  end
end
