# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Index < View
          include Components::Tasks

          BLURBS = {
            Blog::Types::TaskFilter["next"] => ".blurbs.next",
            Blog::Types::TaskFilter["someday"] => ".blurbs.someday",
            Blog::Types::TaskFilter["external"] => ".blurbs.external",
          }.freeze
          CARRIED = :carried_in
          COMPLETED = Blog::Types::TaskTab["completed"]
          EXTERNAL = Blog::Types::TaskTab["external"]
          EMPTY = {
            Blog::Types::TaskList["next"] => ".empty.next",
            Blog::Types::TaskList["someday"] => ".empty.someday",
            Blog::Types::TaskList["external"] => ".empty.external",
          }.freeze
          FINISHED_TODAY = :finished_today
          LIST = { data: { key_list: true } }.freeze
          TITLES = {
            Blog::Types::TaskFilter["next"] => ".next",
            Blog::Types::TaskFilter["someday"] => ".someday",
            Blog::Types::TaskFilter["external"] => ".external",
          }.freeze
          TODAY = Blog::Types::TaskTab["today"]
          UPCOMING = Blog::Types::TaskTab["upcoming"]

          prop :counts, Blog::Types::Hash.map(Blog::Types::String | Blog::Types::Symbol, Blog::Types::Integer)
          prop :filters, Blog::Types::Hash
          prop :lead, Blog::Types::Integer.optional
          prop :planned, Blog::Types::Array.of(Blog::Types::Hash)
          prop :pool, Blog::Types::String
          prop :pools, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)))
          prop :tab, Blog::Types::TaskTab
          prop :tasks, Blog::Types::Instance(Blog::Structs::Paged)
          prop :today, Blog::Types::Date
          prop :waiting, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            PageHead(title: t(".heading"), sub:) do
              Filters(tab: @tab, query: @filters[:query], range:)
              BulkToggle(form: Bulk::ID) if bulk?
              CreateButton()
            end
            Tabs(counts: @counts, tab: @tab, query: @filters[:query], range:, saved_views: @filters[:saved_views])
            body
            p(class: "task-note") { t(".footnote") }
          end

          private

          def archive
            Card(**LIST) do |card|
              card.side { span(class: "card-note") { t(".shown", count: @tasks.rows.size) } }
              archived
            end
          end

          def archived
            return Empty { t(filtering? ? ".empty.completed_no_match" : ".empty.completed") } if days.empty?

            days.each { |(date, tasks)| CompletedDay(date:, tasks:, today: @today) }
            pager
          end

          def body
            return upcoming if upcoming?
            return sprint if today?
            return archive if completed?

            list
          end

          def bulk? = !upcoming? && !completed?

          def carried = @counts.fetch(CARRIED)

          def completed? = @tab == COMPLETED

          def days = @days ||= @tasks.rows.group_by { Blog::TimeZone.today(it.completed_at) }.to_a

          def empty_key = today? ? ".empty.today" : EMPTY.fetch(@tab)

          def external? = @tab == EXTERNAL

          def filtering? = !@filters[:query].empty? || range.any?

          def list
            Card(title: list_title, class: "task-list", **LIST) do |card|
              card.side do
                ImportActs() if external?
                span(class: "card-note") { open_note }
              end
              p(class: "card-blurb") { t(BLURBS.fetch(@tab)) } if BLURBS.key?(@tab)
              rows
              QuickAdd(filter: @tab, placeholder: t(".add_to", list: @tab)) unless external?
            end
          end

          def list_title = today? ? t(".sprint", date: l(@today, format: :short)) : t(TITLES.fetch(@tab))

          def open_note
            counts = [t(".open", count: filtering? ? @tasks.rows.size : @counts.fetch(@tab))]
            counts << t(".carried_in", count: carried) if today? && carried.positive?

            dotted(*counts)
          end

          def pager = Pager(page: @tasks, route: :admin_tasks, params: pager_params)

          def pager_params = { filter: @tab, q: (@filters[:query] unless @filters[:query].empty?), **range }.compact

          def range = completed? ? @filters.slice(:from, :to).compact : Blog::Constants::EMPTY_HASH

          def row(task)
            Row(task:, filter: @tab, today: @today, lead: @lead, ordered: !filtering?, scheduled:, bulk: Bulk::ID,
                large: today?)
          end

          def rows
            return Empty { t(filtering? ? ".empty.no_match" : empty_key) } if @tasks.rows.empty?

            Bulk(filter: @tab, page: @tasks.number, query: @filters[:query])
            @tasks.rows.each { row(it) }
            pager
          end

          def scheduled = (@today if today?)

          def sprint
            div(class: "g-main") do
              list
              PullColumn(counts: @counts, pool: @pool, pools: @pools)
            end
          end

          def sub
            dotted(
              t(".sprint_on", date: l(@today, format: :long)),
              t(".open_in_today", count: @counts.fetch(TODAY)),
              t(".carried_in", count: carried),
              t(".finished_today", count: @counts.fetch(FINISHED_TODAY)),
              t(".upcoming_count", count: @counts.fetch(UPCOMING)),
            )
          end

          def today? = @tab == TODAY

          def upcoming
            UpcomingSprints(planned: @planned, today: @today, waiting: @waiting)
          end

          def upcoming? = @tab == UPCOMING
        end
      end
    end
  end
end
