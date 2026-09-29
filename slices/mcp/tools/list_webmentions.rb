# frozen_string_literal: true

module MCP
  module Tools
    class ListWebmentions < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          page: Paging::PAGE,
          status: {
            type: "string",
            enum: Blog::Types::WebmentionStatus.values,
            description: "only webmentions in this status; every status when you leave it out",
          },
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "List the webmentions received over a range of days, newest first: each with the blog post it " \
                  "names, its type, its status, its source and author, and its excerpt. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, status: nil, page: 1)
          first = Blog::TimeZone.parse_day(from)
          last = Blog::TimeZone.parse_day(to)
          return refuse("give from and to as days, such as 2026-01-01") unless first && last
          return refuse("from comes after to") if first > last

          requested = page(page, server_context)
          found = webmentions_received_in(server_context).call(from: first, to: last, page: requested, status:)

          answer(
            from: first.iso8601,
            to: last.iso8601,
            webmentions: found.rows.map { entry(it) },
            **Paging.fields(found),
          )
        end

        private

        def entry(mention)
          {
            id: mention.id,
            post_id: mention.post_id,
            type: mention.type,
            status: mention.status,
            source_url: mention.source_url,
            author_name: mention.author_name,
            author_url: mention.author_url,
            excerpt: mention.excerpt,
            received_at: mention.received_at.utc.iso8601,
          }
        end
      end
    end
  end
end
