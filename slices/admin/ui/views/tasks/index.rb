# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Index < View
          include Components::Tasks

          BLURBS = {
            Blog::Types::TaskFilter["today"] => ".blurbs.today",
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
          LABELS = {
            Blog::Types::TaskFilter["today"] => ".sprint",
            Blog::Types::TaskFilter["next"] => ".on_deck",
            Blog::Types::TaskFilter["someday"] => ".backlog",
            Blog::Types::TaskFilter["external"] => ".imported",
          }.freeze
          LIVE = { class: "card-live" }.freeze
          SEPARATOR = " · "
          TITLES = {
            Blog::Types::TaskFilter["today"] => ".today",
            Blog::Types::TaskFilter["next"] => ".next",
            Blog::Types::TaskFilter["someday"] => ".someday",
            Blog::Types::TaskFilter["external"] => ".external",
          }.freeze
          TODAY = Blog::Types::TaskTab["today"]
          UPCOMING = Blog::Types::TaskTab["upcoming"]

          def initialize(counts:, filters:, planned:, pool:, pools:, tab:, tasks:, today:, waiting:)
            super()
            @counts = counts
            @filters = filters
            @plan = { planned:, pool:, pools:, waiting: }
            @tab = tab
            @tasks = tasks
            @today = today
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              Filters(tab: @tab, **@filters)
              CreateButton()
            end
            Tabs(counts: @counts, tab: @tab, **@filters)
            body
            p(class: "task-note") { t(".footnote") }
          end

          private

          def archive
            Card(label: t(".archive"), title: t(".completed")) do |card|
              card.side { span(class: "card-note") { t(".shown", count: @tasks.rows.size) } }
              archived
            end
          end

          def archived
            return Empty { t(filtering? ? ".empty.completed_no_match" : ".empty.completed") } if days.empty?

            days.each { |(date, tasks)| day(date, tasks) }
            pager
          end

          def body
            return upcoming if upcoming?
            return planner if planning?
            return archive if completed?

            list
          end

          def carried = @counts.fetch(CARRIED)

          def completed? = @tab == COMPLETED

          def day(date, tasks)
            CompletedDay(date:, tasks:, today: @today)
          end

          def days = @days ||= @tasks.rows.group_by { Blog::TimeZone.today(it.completed_at) }.to_a

          def external? = @tab == EXTERNAL

          def filtering? = !@filters[:query].empty?

          def label = t(LABELS.fetch(@tab), date: l(@today, format: :short))

          def list
            Card(label:, title: t(TITLES.fetch(@tab)), **(today? ? LIVE : Dry::Core::Constants::EMPTY_HASH)) do |card|
              card.side do
                span(class: "card-note") { open_note }
                SyncButton() if external?
              end
              p(class: "card-blurb") { t(BLURBS.fetch(@tab)) }
              rows
            end
          end

          def open_note
            counts = [t(".open", count: filtering? ? @tasks.rows.size : @counts.fetch(@tab))]
            counts << t(".carried_in", count: carried) if today? && carried.positive?

            counts.join(SEPARATOR)
          end

          def pager = Pager(page: @tasks, route: :admin_tasks, params: pager_params)

          def pager_params = filtering? ? { filter: @tab, q: @filters[:query] } : { filter: @tab }

          def planner
            Planner(counts: @counts, date: @today, pool: @plan[:pool], pools: @plan[:pools])
          end

          def planning? = today? && @tasks.rows.empty? && !filtering?

          def row(task, index)
            first = index.zero? && @tasks.previous_number.nil?
            last = index == @tasks.rows.size - 1 && !@tasks.more

            Row(task:, filter: @tab, today: @today, first:, last:, page: @tasks.number, scheduled:)
          end

          def rows
            return Empty { t(filtering? ? ".empty.no_match" : EMPTY.fetch(@tab)) } if @tasks.rows.empty?

            @tasks.rows.each_with_index { |task, index| row(task, index) }
            pager
          end

          def scheduled = (@today if today?)

          def sub
            [
              t(".sprint_on", date: l(@today, format: :long)),
              t(".open_in_today", count: @counts.fetch(TODAY)),
              t(".carried_in", count: carried),
              t(".finished_today", count: @counts.fetch(FINISHED_TODAY)),
              t(".upcoming_count", count: @counts.fetch(UPCOMING)),
            ].join(SEPARATOR)
          end

          def today? = @tab == TODAY

          def upcoming
            UpcomingSprints(planned: @plan[:planned], today: @today, waiting: @plan[:waiting])
          end

          def upcoming? = @tab == UPCOMING
        end
      end
    end
  end
end
