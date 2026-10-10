# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Index < View
          include Components::Tasks

          COMPLETED = Blog::Types::TaskTab["completed"]
          FINISHED_TODAY = :finished_today
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
              Filters(tab: @tab, query:, range:)
              BulkToggle(form: Bulk::ID) if bulk?
              CreateButton()
            end
            Tabs(counts: @counts, tab: @tab, query:, range:, saved_views: @filters[:saved_views])
            body
            p(class: "task-note") { t(".footnote") }
          end

          private

          def body
            case @tab
              when UPCOMING then UpcomingSprints(planned: @planned, today: @today, waiting: @waiting)
              when TODAY then sprint
              when COMPLETED then CompletedCard(query:, range:, tasks: @tasks, today: @today)
              else list
            end
          end

          def bulk? = @tab != UPCOMING && @tab != COMPLETED

          def list = ListCard(counts: @counts, lead: @lead, query:, tab: @tab, tasks: @tasks, today: @today)

          def query = @filters[:query]

          def range = @tab == COMPLETED ? @filters.slice(:from, :to).compact : Blog::Constants::EMPTY_HASH

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
              t(".carried_in", count: @counts.fetch(ListCard::CARRIED)),
              t(".finished_today", count: @counts.fetch(FINISHED_TODAY)),
              t(".upcoming_count", count: @counts.fetch(UPCOMING)),
            )
          end
        end
      end
    end
  end
end
