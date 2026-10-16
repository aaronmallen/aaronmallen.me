# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Performance
        class Show < View
          include Components::Performance

          ROWS = Blog::Types::Array.of(Blog::Types::Hash)

          prop :days, ROWS
          prop :jobs, ROWS
          prop :range, Blog::Types::AnalyticsRange
          prop :routes, ROWS

          def view_template
            content_for(:live_tables, Blog::Constants::EMPTY_ARRAY)
            PageHead(title: t(".heading"), sub: t(".lede", count: @range))
            Components::Analytics::Tabs(current: :performance, range: @range, action: path(:admin_performance))

            div(class: "stack") do
              DailyChart(days: @days, title: t(".per_day"), note: t(".all_routes"))
              routes_card
              jobs_card
            end
          end

          private

          def jobs_card
            Card(title: t(".jobs"), note: t(".job_count", count: @jobs.size), empty: (t(".no_jobs") if @jobs.empty?)) do
              TimingTable(heading: t(".job"), rows: @jobs) { |row| span(class: "perf-path") { row[:job] } }
            end
          end

          def route_link(row)
            href = path(:admin_performance_requests, route: row[:route], verb: row[:verb], range: @range)

            a(class: "perf-route", href:) { RouteLabel(verb: row[:verb], route: row[:route]) }
          end

          def routes_card
            note = t(".route_count", count: @routes.size)

            Card(title: t(".routes"), note:, empty: (t(".no_routes") if @routes.empty?)) do
              TimingTable(heading: t(".route"), rows: @routes, browser: true) { |row| route_link(row) }
            end
          end
        end
      end
    end
  end
end
