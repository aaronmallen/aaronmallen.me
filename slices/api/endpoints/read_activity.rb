# frozen_string_literal: true

module API
  module Endpoints
    class ReadActivity < Endpoint
      KINDS = Blog::Types::ActivityKind.values

      SCHEMA = {
        additionalProperties: false,
        properties: {
          **Blog::DayWindow::WINDOW,
          kinds: {
            type: "array",
            items: { type: "string", enum: KINDS },
            description: "which kinds to read; every kind when you leave it out",
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

      REPLY = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
          count: Schema::INTEGER,
          partial: Schema::BOOLEAN,
          activity: Schema.list(Serializers::Activity.reference),
        },
        optional: { continue_to: Schema::DAY },
      ).freeze

      include Deps[activity_between: "activity.queries.activity_between"]

      def handle(from:, to:, kinds: nil, repos: nil, tags: nil, text: nil)
        case Blog::DayWindow.days(from, to)
        in Success[first, last] then Success(window(first, last, { kinds:, repos:, tags:, text: }))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def found(from, to, filters, limit)
        activity_between.call(
          from:,
          to:,
          types: types(filters[:kinds]),
          repos: Array(filters[:repos]),
          tags: Array(filters[:tags]),
          text: filters[:text],
          limit:,
        )
      end

      def types(chosen)
        asked = KINDS & Array(chosen)

        asked.empty? ? KINDS : asked
      end

      def window(first, last, filters)
        page = Blog::DayWindow.page(first, last, day: :occurred_on.to_proc) do |from, to, limit|
          found(from, to, filters, limit)
        end
        rows = page.fetch(:rows)

        {
          from: first.iso8601,
          to: last.iso8601,
          count: rows.length,
          **page.except(:rows),
          activity: serialized(Serializers::Activity, rows),
        }
      end
    end
  end
end
