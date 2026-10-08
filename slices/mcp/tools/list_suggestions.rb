# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ListSuggestions < Base
      POST = SuggestEdits::POST
      SOCIAL_POST = SuggestEdits::SOCIAL_POST

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::Helpers::DayWindow::RANGE,
          page: Blog::Helpers::Paging::PAGE,
        },
        required: %w[from to],
      }.freeze

      description "List the sets of suggested edits made over a range, newest first, each with the blog post or " \
                  "social post it targets and every edit in it: the original text, its replacement, the reason " \
                  "and its status. A pending edit waits on the author, a stale one no longer matches the text, " \
                  "and accepted and rejected ones are settled. Accept or reject open edits with " \
                  "accept_suggestion_edits and reject_suggestion_edits. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range. #{Blog::Helpers::Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:, page: 1)
          case Blog::Helpers::DayWindow.days(from, to)
            in Success[first, last] then listed(first..last, page(page, server_context), server_context)
            in Failure(message) then refuse(message)
          end
        end

        private

        def edit(row)
          {
            id: row.id,
            part: row.part,
            original: row.original,
            replacement: row.replacement,
            reason: row.reason,
            status: row.status,
          }
        end

        def listed(range, page, server_context)
          found = dep(:suggestion_queries, server_context).created_between(from: range.first, to: range.last, page:)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            suggestions: found.rows.map { summary(it) },
            **Blog::Helpers::Paging.fields(found),
          )
        end

        def summary(suggestion)
          {
            id: suggestion.id,
            **target(suggestion),
            created_at: suggestion.created_at.utc.iso8601,
            edits: suggestion.edits.map { edit(it) },
          }
        end

        def target(suggestion)
          return { target: POST, target_id: suggestion.post_id } if suggestion.post_id

          { target: SOCIAL_POST, target_id: suggestion.social_post_id }
        end
      end
    end
  end
end
