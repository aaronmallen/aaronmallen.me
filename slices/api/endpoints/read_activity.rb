# frozen_string_literal: true

module API
  module Endpoints
    class ReadActivity < Endpoint
      KINDS = Blog::Types::ActivityKind.values
      SCOPED = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Helpers::DayWindow::WINDOW,
          **Helpers::Schema::CREDITS,
          kinds: {
            type: "array",
            items: { type: "string", enum: KINDS },
            description: "which kinds to read; every kind when you leave it out. workout needs the health scope",
          },
          repos: {
            type: "array",
            items: { type: "string" },
            description: "repository names, with or without the owner; a name narrows commits and nothing else",
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "tags on journal entries, tasks and decisions; a comment or session takes its owner's tags",
          },
          text: { type: "string", description: "free text to match against the row" },
        },
        required: %w[from to],
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          count: Helpers::Schema::INTEGER,
          activity: Helpers::Schema.list(Serializers::Activity.reference),
        },
        more: { continue_to: Helpers::Schema::DAY },
      ).freeze

      include Deps[
        activity_queries: "activity.repos.activity_queries",
        contributor_terms: "contracts.contributor_terms_contract",
      ]

      def handle(from:, to:, scopes:, kinds: nil, repos: nil, tags: nil, text: nil, **credited)
        filters = { kinds: types(kinds, scopes), repos:, tags:, text:, credits: contributor_terms.call(credited).to_h }

        case Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(window(first, last, filters))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def found(from, to, filters, limit)
        activity_queries.between(
          from:,
          to:,
          types: filters[:kinds],
          repos: Array(filters[:repos]),
          tags: Array(filters[:tags]),
          text: filters[:text],
          **filters[:credits],
          limit:,
        )
      end

      def types(chosen, scopes)
        shown = activity_kinds(scopes)

        Array(chosen).empty? ? shown : shown & chosen
      end

      def window(first, last, filters)
        page = Helpers::DayWindow.page(first, last, settings, day: :occurred_on.to_proc) do |from, to, limit|
          found(from, to, filters, limit)
        end
        rows = page.fetch(:rows)

        page.except(:rows).merge(activity: serialized(Serializers::Activity, rows, views: activity_queries.views(rows)))
      end
    end
  end
end
