# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Index < View
          include Components::Tasks

          ALL_TYPES = "all"
          BLURBS = {
            Blog::Types::TaskFilter["today"] => ".blurbs.today",
            Blog::Types::TaskFilter["next"] => ".blurbs.next",
            Blog::Types::TaskFilter["someday"] => ".blurbs.someday",
          }.freeze
          CARRIED = :carried_in
          COMPLETED = Blog::Types::TaskTab["completed"]
          EMPTY = {
            Blog::Types::TaskList["next"] => ".empty.next",
            Blog::Types::TaskList["someday"] => ".empty.someday",
          }.freeze
          FINISHED_TODAY = :finished_today
          LABELS = {
            Blog::Types::TaskFilter["today"] => ".sprint",
            Blog::Types::TaskFilter["next"] => ".on_deck",
            Blog::Types::TaskFilter["someday"] => ".backlog",
          }.freeze
          LIVE = { class: "card-live" }.freeze
          SEPARATOR = " · "
          TITLES = {
            Blog::Types::TaskFilter["today"] => ".today",
            Blog::Types::TaskFilter["next"] => ".next",
            Blog::Types::TaskFilter["someday"] => ".someday",
          }.freeze
          TODAY = Blog::Types::TaskTab["today"]
          UPCOMING = Blog::Types::TaskTab["upcoming"]

          def initialize(
            counts:, editing:, filters:, linking:, planned:, pool:, pools:, tab:, task_types:, tasks:, today:,
            waiting:
          )
            super()
            @counts = counts
            @filters = filters
            @editors = { editing:, linking: }
            @plan = { planned:, pool:, pools:, waiting: }
            @tab = tab
            @task_types = task_types
            @tasks = tasks
            @today = today
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              Filters(tab: @tab, types: @task_types, **@filters)
              types_link
              CreateButton()
            end
            Tabs(counts: @counts, tab: @tab, **@filters)
            body
            p(class: "task-note") { t(".footnote") }
          end

          private

          def archive
            Card(label: t(".archive"), title: t(".completed")) do |card|
              card.side { span(class: "card-note") { t(".shown", count: @tasks.size) } }
              next Empty { t(filtering? ? ".empty.completed_no_match" : ".empty.completed") } if days.empty?

              days.each { |(date, tasks)| day(date, tasks) }
            end
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
            CompletedDay(date:, tasks:, today: @today, types: @task_types, **@editors)
          end

          def days = @days ||= @tasks.group_by { Blog::TimeZone.today(it.completed_at) }.to_a

          def filtering? = !@filters[:query].empty? || @filters[:type] != ALL_TYPES

          def label = t(LABELS.fetch(@tab), date: l(@today, format: :short))

          def list
            Card(label:, title: t(TITLES.fetch(@tab)), **(today? ? LIVE : Dry::Core::Constants::EMPTY_HASH)) do |card|
              card.side { span(class: "card-note") { open_note } }
              p(class: "card-blurb") { t(BLURBS.fetch(@tab)) }
              rows
            end
          end

          def open_note
            counts = [t(".open", count: @tasks.size)]
            counts << t(".carried_in", count: carried) if today? && carried.positive?

            counts.join(SEPARATOR)
          end

          def planner
            Planner(date: @today, pool: @plan[:pool], pools: @plan[:pools], task_types: @task_types)
          end

          def planning? = today? && @tasks.empty? && !filtering?

          def rows
            return Empty { t(filtering? ? ".empty.no_match" : EMPTY.fetch(@tab)) } if @tasks.empty?

            last = @tasks.size - 1
            @tasks.each_with_index do |task, index|
              Row(
                task:, filter: @tab, today: @today, types: @task_types, first: index.zero?, last: index == last,
                scheduled:, **@editors,
              )
            end
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

          def types_link
            a(class: "btn", href: path(:admin_task_types)) do
              i(class: "fa-solid fa-sliders", aria: { hidden: "true" })
              span { t(".types") }
            end
          end

          def upcoming
            UpcomingSprints(
              linking: @editors[:linking], planned: @plan[:planned], task_types: @task_types, today: @today,
              waiting: @plan[:waiting],
            )
          end

          def upcoming? = @tab == UPCOMING
        end
      end
    end
  end
end
