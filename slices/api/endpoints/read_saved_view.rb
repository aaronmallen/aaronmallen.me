# frozen_string_literal: true

module API
  module Endpoints
    class ReadSavedView < Endpoint
      BAD_DAY = "give continue_to as a day, such as 2026-01-01"
      NO_SPRINT = "could not open today's sprint"
      ACTIVITY = Blog::Types::SavedViewScreen["activity"]
      TASKS = Blog::Types::SavedViewScreen["tasks"]

      SERIALIZERS = {
        ACTIVITY => Serializers::Activity,
        Blog::Types::SavedViewScreen["journal"] => Serializers::JournalEntry,
        Blog::Types::SavedViewScreen["posts"] => Serializers::Post,
        TASKS => Serializers::Task,
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: SavedViews::ID,
          page: Blog::Paging::PAGE.merge(description: "the page to read on a tasks or posts view, counting from 1"),
          continue_to: {
            type: "string",
            description: "on a journal or activity view, the continue_to of the last answer, to read the next window",
          },
        },
        required: ["id"],
      }.freeze

      REPLY = Schema.object(
        {
          saved_view: Serializers::SavedView.reference,
          count: Schema::INTEGER,
          partial: Schema::BOOLEAN,
          records: Schema.list({ anyOf: SERIALIZERS.values.map(&:reference) }),
        },
        optional: { next_page: Schema::INTEGER, continue_to: Schema::DAY },
      ).freeze

      include Deps[
        activity_view_queries: "repos.activity_view_queries",
        list_saved_view_records: "operations.list_saved_view_records",
        saved_view_queries: "saved_views.repos.saved_view_queries",
      ]

      def handle(id:, page: 1, continue_to: nil)
        cursor = continue_to && Blog::TimeZone.parse_day(continue_to)
        return invalid(continue_to: [BAD_DAY]) if continue_to && cursor.nil?

        view = saved_view_queries.by_id(id)
        return not_found(Wording.missing("saved view", id)) if view.nil?

        case list_saved_view_records.call(view, page:, continue_to: cursor)
          in Success(found) then Success(answered(view, found))
          else failed(NO_SPRINT)
        end
      end

      private

      def answered(view, found)
        rows = found.fetch(:rows)

        {
          saved_view: serialized(Serializers::SavedView, view),
          count: rows.length,
          **found.slice(:partial, :next_page, :continue_to),
          records: records(view.screen, rows, found),
        }
      end

      def records(screen, rows, found)
        return serialized(Serializers::Activity, rows, views: activity_view_queries.views(rows)) if screen == ACTIVITY
        return serialized(SERIALIZERS.fetch(screen), rows) unless screen == TASKS

        sprint_on = found.fetch(:sprint_on)
        rows.map { serialized(Serializers::Task, it, sprint_on: sprint_on.fetch(it.id)) }
      end
    end
  end
end
