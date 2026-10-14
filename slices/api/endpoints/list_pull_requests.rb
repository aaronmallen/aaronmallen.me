# frozen_string_literal: true

module API
  module Endpoints
    class ListPullRequests < Endpoint
      DAY = ->(pull_request) { Blog::TimeZone.today(pull_request.moved_at) }

      SCHEMA = {
        additionalProperties: false,
        properties: { from: Blog::Helpers::DayWindow::DAYS, to: Blog::Helpers::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          count: Helpers::Schema::INTEGER,
          pull_requests: Helpers::Schema.list(Serializers::PullRequest.reference),
        },
        more: { continue_to: Helpers::Schema::DAY },
      ).freeze

      include Deps[pull_request_queries: "record.repos.pull_request_queries"]

      def handle(from:, to:)
        case Blog::Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last)
        page = Blog::Helpers::DayWindow.page(first, last, day: DAY) do |from, to, limit|
          pull_request_queries.between(from:, to:, limit:)
        end
        rows = page.fetch(:rows)
        window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

        window.merge(pull_requests: serialized(Serializers::PullRequest, rows))
      end
    end
  end
end
