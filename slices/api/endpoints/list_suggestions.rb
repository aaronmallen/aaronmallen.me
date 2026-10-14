# frozen_string_literal: true

module API
  module Endpoints
    class ListSuggestions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { **Helpers::DayWindow::RANGE, page: Helpers::Paging::PAGE },
        required: %w[from to],
      }.freeze

      STATUS = {
        type: "string",
        enum: Blog::Types::SuggestionEditStatus.values,
        description: "pending waits on the author, stale no longer matches the text, the rest are settled",
      }.freeze
      EDIT = Serializers::SuggestionEdit::SCHEMA.merge(
        properties: Serializers::SuggestionEdit::SCHEMA.fetch(:properties).merge(status: STATUS),
      ).freeze

      SUGGESTION = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          target: Suggestions::TARGET,
          target_id: Helpers::Schema::INTEGER,
          created_at: Helpers::Schema::STAMP,
          edits: Helpers::Schema.list(EDIT),
        },
      ).freeze

      REPLY = Helpers::Schema.paged(
        { from: Helpers::Schema::DAY, to: Helpers::Schema::DAY, suggestions: Helpers::Schema.list(SUGGESTION) },
      ).freeze

      include Deps[suggestion_queries: "suggestions.repos.suggestion_queries"]

      def handle(from:, to:, page: 1)
        case Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last, page_of(page)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, page)
        found = suggestion_queries.created_between(from: first, to: last, page:)

        {
          from: first.iso8601,
          to: last.iso8601,
          suggestions: found.rows.map { summary(it) },
          **Helpers::Paging.fields(found),
        }
      end

      def summary(suggestion)
        {
          id: suggestion.id,
          **target(suggestion),
          created_at: suggestion.created_at.utc.iso8601,
          edits: serialized(Serializers::SuggestionEdit, suggestion.edits),
        }
      end

      def target(suggestion)
        return { target: Suggestions::POST, target_id: suggestion.post_id } if suggestion.post_id

        { target: Suggestions::SOCIAL_POST, target_id: suggestion.social_post_id }
      end
    end
  end
end
