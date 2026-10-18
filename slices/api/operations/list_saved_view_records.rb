# frozen_string_literal: true

module API
  module Operations
    class ListSavedViewRecords < Blog::Operation
      ACTIVITY = Blog::Types::SavedViewScreen["activity"]
      ACTIVITY_FIELDS = %i[repo tag contributor agent model].freeze
      COMPLETED = Blog::Types::TaskTab["completed"]
      JOURNAL = Blog::Types::SavedViewScreen["journal"]
      JOURNAL_FIELDS = %i[tag].freeze
      POSTS = Blog::Types::SavedViewScreen["posts"]
      RECURRING = Blog::Types::TaskTab["recurring"]
      TASK_FIELDS = %i[tag contributor agent model].freeze
      TODAY = Blog::Types::TaskTab["today"]
      UPCOMING = Blog::Types::TaskTab["upcoming"]

      include Deps[
        "settings",
        activity_queries: "activity.repos.activity_queries",
        current_sprint: "tasks.operations.current_sprint",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        search_query: "contracts.search_query_contract",
        sprint_queries: "tasks.repos.sprint_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(view, page: 1, continue_to: nil, kinds: Blog::Types::ActivityKind.values, now: Time.now)
        filters = view.filters

        case view.screen
          when ACTIVITY then activity(filters, continue_to, kinds)
          when JOURNAL then journal(filters, continue_to)
          when POSTS then posts(filters, page_of(page))
          else tasks(filters, page_of(page), now)
        end
      end

      private

      def activity(filters, continue_to, kinds)
        window = activity_window(filters.merge("day" => continue_to || filters["day"]))
        search = { types: window[:types] & kinds,
                   **search_query.call(query: filters["q"], fields: ACTIVITY_FIELDS).to_h }

        Helpers::DayWindow.page(window[:from], window[:day], settings, day: :occurred_on.to_proc) do |from, to, limit|
          activity_queries.between(from:, to:, limit:, **search)
        end
      end

      def activity_window(picked) = ::Activity::Contracts::FiltersContract.new.call(picked).to_h

      def closed_range(filters)
        range = ::Tasks::Contracts::ClosedRangeContract.new.call(from: filters["from"], to: filters["to"])

        range.success? ? range.to_h : Blog::Constants::EMPTY_HASH
      end

      def finished(page, filters, search)
        found = task_queries.finished(page:, **closed_range(filters), **search)

        listed(found, found.rows.to_h { [it.id, it.sprint&.sprint_date] })
      end

      def journal(filters, continue_to)
        search = search_query.call(query: filters["q"], fields: JOURNAL_FIELDS).to_h
        last_day = continue_to || Blog::Types::DateParam[filters["to"]]
        found = journal_entry_queries.days(size: Helpers::DayWindow.size(settings), to: last_day, **search)

        { rows: found.rows.flat_map(&:last), **paging(found.older_query) }
      end

      def listed(found, sprint_on) = { rows: found.rows, sprint_on:, **Helpers::Paging.fields(found) }

      def open_tasks(tab, sprint, page, search)
        found = task_queries.list(tab, sprint:, page:, **search)
        day = tab == TODAY ? sprint.sprint_date : nil

        listed(found, found.rows.to_h { [it.id, day] })
      end

      def page_of(number) = Helpers::Page.of(number, settings)

      def paging(older) = older ? { partial: true, continue_to: older.fetch(:to) } : { partial: false }

      def posts(filters, page)
        found = post_queries.by_filter(Blog::Types::PostFilterParam[filters["status"]], page)

        { rows: found.rows, **Helpers::Paging.fields(found) }
      end

      def recurring
        rows = task_queries.recurring

        { rows:, sprint_on: rows.to_h { [it.id, it.sprint&.sprint_date] }, partial: false }
      end

      def tasks(filters, page, now)
        tab = Blog::Types::TaskTabParam[filters["filter"]]
        search = search_query.call(query: filters["q"], fields: TASK_FIELDS).to_h

        case tab
          when COMPLETED then finished(page, filters, search)
          when UPCOMING then upcoming(Blog::TimeZone.local_date(now), search)
          when RECURRING then recurring
          else open_tasks(tab, step(current_sprint.call(now:)), page, search)
        end
      end

      def upcoming(today, search)
        planned = sprint_queries.after(today)
        days = planned.to_h { [it.id, it.sprint_date] }
        rows = task_queries.planned(planned, **search)

        { rows:, sprint_on: rows.to_h { [it.id, days[it.sprint_id]] }, partial: false }
      end
    end
  end
end
