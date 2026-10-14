# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Performance
        class Requests < View
          include Components::Performance

          HEADINGS = %i[query_count query_time].to_h { [it, ".#{it}"] }.freeze
          SERVER_ERROR = 500

          prop :days, Blog::Types::Array.of(Blog::Types::Hash)
          prop :range, Blog::Types::AnalyticsRange
          prop :route, Blog::Types::String.optional
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :verb, Blog::Types::String.optional

          def view_template
            head
            Components::Analytics::Tabs(
              current: :performance, range: @range, action: path(:admin_performance_requests),
              keep: { route: @route, verb: @verb },
            )

            div(class: "stack") do
              DailyChart(days: @days, title: t(".per_day"), note: t(".requests", count: total, formatted: count(total)))
              slowest_card
            end
          end

          private

          def count(value) = Blog::Helpers::Figures.count(value)

          def head
            PageHead(title: dotted(@verb, @route || t(".no_route")), sub: t(".lede", count: @range)) do |head|
              head.heading { span(class: "perf-title") { RouteLabel(verb: @verb.to_s, route: @route) } }
              BackLink(href: path(:admin_performance, range: @range), variant: :gh, small: true) { t(".back") }
            end
          end

          def headings
            tr do
              th(class: "tbl-h") { t(".when") }
              th(class: "tbl-h num") { t(".status") }
              th(class: "tbl-h num perf-key-col") { t(".duration") }
              HEADINGS.each_value { |key| th(class: "tbl-h num") { t(key) } }
            end
          end

          def ms(value) = t(".ms", value: count(value.round))

          def requests
            return Empty { t(".empty") } if @rows.empty?

            div(class: "tbl-scroll") do
              table(class: "tbl perf-table") do
                thead { headings }
                tbody { @rows.each { row(it) } }
              end
            end
          end

          def row(entry)
            tr do
              td(class: "tbl-c") { Moment(at: entry[:occurred_at]) }
              td(class: "tbl-c num") { status(entry[:status]) }
              td(class: "tbl-c num perf-key-col") { time(entry[:duration]) }
              td(class: "tbl-c num") { entry[:query_count].to_s }
              td(class: "tbl-c num") { ms(entry[:query_time]) }
            end
          end

          def slowest = @slowest ||= @rows.map { it[:duration] }.max

          def slowest_card
            Card(title: t(".slowest")) do |card|
              card.side { span(class: "meta") { t(".shown", shown: count(@rows.size), total: count(total)) } }
              requests
            end
          end

          def status(code) = span(class: ["perf-status", ("bad" if code >= SERVER_ERROR)]) { code.to_s }

          def time(duration)
            span(class: "perf-time-bar", aria: { hidden: "true" }) do
              i(style: "width: #{Blog::Helpers::Figures.share(duration, slowest)}%")
            end
            plain ms(duration)
          end

          def total = @total ||= @days.sum { it[:count] }
        end
      end
    end
  end
end
