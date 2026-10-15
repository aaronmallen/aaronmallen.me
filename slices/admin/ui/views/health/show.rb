# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Health
        class Show < View
          include Components::Health

          LIVE_TABLES = %w[
            commits health_days journal_entries oauth_clients oauth_tokens pull_requests work_sessions workouts
          ].freeze

          prop :clients, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :day, Blog::Types::Date
          prop :report, Blog::Types::Instance(::Health::Structs::Report)
          prop :span, Blog::Types::HealthSpan
          prop :today, Blog::Types::Date
          prop :tokens, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub:) { services_link }
            spans
            div(class: "g-main") do
              Card(title: t(".grid")) do
                Grid(report: @report, day: @day, span: @span)
                DayDetail(**detail)
              end
              aside(class: "stack stick") { side }
            end
          end

          private

          def asleep = @report.days.filter_map(&:minutes_asleep)

          def detail
            {
              day: @report.days.find { it.day == @day }, baseline: @report.baseline, first: @report.from,
              span: @span, today: @today, workouts: @report.workouts,
            }
          end

          def services_link
            Button(href: path(:admin_services), icon: "fa-solid fa-heart-pulse") { t(".google_health") }
          end

          def side
            PatternsCard(patterns: @report.patterns, span: @span)
            AgentsCard(clients: @clients, tokens: @tokens)
          end

          def span_link(span)
            { href: path(:admin_health, span:), text: t(".days", count: span), current: span == @span }
          end

          def spans
            div(class: "health-bar") do
              SegmentedLinks(label: t(".span"), items: Blog::Types::HealthSpan.values.map { span_link(it) })
              Hint(inline: true) { t(".hint") }
            end
          end

          def sub
            workouts = t(".workouts", count: @report.workouts.size)
            return t(".no_sleep", count: @span, workouts:) if asleep.empty?

            average = Blog::Helpers::Figures.minutes(Blog::Helpers::Figures.average(asleep.sum, asleep.size))
            t(".sub", count: @span, asleep: average, workouts:)
          end
        end
      end
    end
  end
end
