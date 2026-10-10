# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class Heat < Component
          FLOOR = 22
          RANGE = 78
          AMOUNTS = { done: ".amounts.done", commits: ".amounts.commits", journal: ".amounts.journal" }.freeze
          ROWS = {
            done: ".rows.done", commits: ".rows.commits", worked_seconds: ".rows.worked", journal: ".rows.journal",
          }.freeze
          WEEK = Blog::Types::ReviewPeriod["week"]
          WHOLE = { "week" => ".whole.week", "month" => ".whole.month" }.freeze

          prop :days, Blog::Types::Hash.map(Blog::Types::Date, Blog::Types::Hash)
          prop :period, Blog::Types::ReviewPeriod
          prop :focus, Blog::Types::Date.optional
          prop :today, Blog::Types::Date
          prop :keep, Blog::Types::Hash

          def view_template
            section(class: "card review-heat", id: "review-heat", aria: { label: t(".label") }) do
              div(class: "review-heat-map", style: "--days: #{@days.size}") do
                span
                @days.each_key { head(it) }
                ROWS.each { |row, label| row(row, label) }
              end
              foot
            end
          end

          private

          def amount(row, value)
            AMOUNTS.key?(row) ? t(AMOUNTS.fetch(row), count: value) : Blog::Helpers::Figures.hours(value)
          end

          def cell(day, row, value)
            said = "#{l(day, format: :short)} · #{amount(row, value)}"
            pick(day, class: ["review-heat-cell", ("on" if day == @focus), ("dim" if @focus && day != @focus)],
                      style: "--heat: #{shade(row, value)}%", title: said, aria: { label: said })
          end

          def foot
            div(class: "review-heat-foot") do
              @focus ? scoped : span { t(".hint") }
            end
          end

          def head(day)
            pick(day, class: ["review-heat-day", ("on" if day == @focus), ("today" if day == @today)],
                      aria: { label: l(day, format: :full) }) do
              plain "#{l(day, format: :day_name)} " if @period == WEEK
              b { day.day.to_s }
            end
          end

          def href(day) = path(:admin_review, **@keep, **{ focus: day&.iso8601 }.compact)

          def peaks = @peaks ||= ROWS.keys.to_h { |row| [row, [1, *@days.values.map { it.fetch(row) }].max] }

          def pick(day, aria:, **attributes, &)
            return span(**attributes, aria: { disabled: true }, &) if day > @today

            picked = day == @focus
            a(**attributes, href: href((day unless picked)), aria: { **aria, current: ("true" if picked) }, &)
          end

          def row(row, label)
            span(class: "review-heat-label") { t(label) }
            @days.each { |day, counts| cell(day, row, counts.fetch(row)) }
          end

          def scoped
            span do
              b { l(@focus, format: :full) }
              plain t(".scoped")
            end
            a(class: "review-chip", href: href(nil)) do
              plain t(WHOLE.fetch(@period))
              Icon("fa-solid fa-xmark")
            end
          end

          def shade(row, value) = value.zero? ? 0 : FLOOR + (RANGE * value / peaks.fetch(row))
        end
      end
    end
  end
end
