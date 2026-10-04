# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewTasks
      COMPLETED = Blog::Types::TaskTab["completed"]
      FIELDS = %i[tag].freeze
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]

      include Dry::Monads[:result]
      include Deps[
        "settings",
        current_sprint: "tasks.operations.current_sprint",
        list_finished_tasks: "tasks.queries.list_finished_tasks",
        list_tasks: "tasks.queries.list_tasks",
        planned_tasks: "tasks.queries.planned_tasks",
        sprints_after: "tasks.queries.sprints_after",
      ]

      def call(filters, page: 1, now: Time.now, **)
        tab = Blog::Types::TaskTabParam[filters["filter"]]
        search = Blog::SearchQuery.parse(filters["q"], fields: FIELDS)

        case tab
        when COMPLETED then Success(finished(page_of(page), search))
        when UPCOMING then Success(upcoming(Blog::TimeZone.today(now), search))
        else current_sprint.call(now:).fmap { open_tasks(tab, it, page_of(page), search) }
        end
      end

      private

      def finished(page, search)
        found = list_finished_tasks.call(page:, **search)

        listed(found, found.rows.to_h { [it.id, it.sprint&.sprint_date] })
      end

      def listed(found, sprint_on) = { rows: found.rows, sprint_on:, **Blog::Paging.fields(found) }

      def open_tasks(tab, sprint, page, search)
        found = list_tasks.call(tab, sprint:, page:, **search)
        day = tab == TODAY ? sprint.sprint_date : nil

        listed(found, found.rows.to_h { [it.id, day] })
      end

      def page_of(number) = Blog::Page.new(number:, size: settings.page_size[:mcp])

      def upcoming(today, search)
        planned = sprints_after.call(today)
        days = planned.to_h { [it.id, it.sprint_date] }
        rows = planned_tasks.call(planned, **search)

        { rows:, sprint_on: rows.to_h { [it.id, days[it.sprint_id]] }, partial: false }
      end
    end
  end
end
