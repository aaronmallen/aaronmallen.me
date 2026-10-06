# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class PeriodPager < Component
          MONTH = Blog::Types::ReviewPeriod["month"]
          PERIODS = { "week" => ".periods_week", "month" => ".periods_month" }.freeze
          STEPS = {
            "week" => {
              label: ".week.label", previous: ".week.previous", next: ".week.next", current: ".week.current",
            },
            "month" => {
              label: ".month.label", previous: ".month.previous", next: ".month.next", current: ".month.current",
            },
          }.freeze
          WEEK = 7

          prop :period, Blog::Types::ReviewPeriod
          prop :on, Blog::Types::Date
          prop :from, Blog::Types::Date
          prop :to, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            SegmentedLinks(label: t(".periods"), items: PERIODS.keys.map { period_link(it) })
            nav(class: "review-pager", aria: { label: t(steps[:label]) }) { arrows }
          end

          private

          def arrows
            step(earlier, rel: "prev", label: steps[:previous], icon: "fa-arrow-left")
            a(class: "btn", href: href(@period)) { t(steps[:current]) } unless current?
            step(later, rel: "next", label: steps[:next], icon: "fa-arrow-right")
          end

          def current? = (@from..@to).cover?(@today)

          def earlier = month? ? @on.prev_month : @on - WEEK

          def href(period, day = nil)
            path(:admin_review, **{ period: (period if period == MONTH), day: day&.iso8601 }.compact)
          end

          def later = month? ? @on.next_month : @on + WEEK

          def month? = @period == MONTH

          def period_link(period)
            {
              href: href(period, (@on unless @on == @today)),
              text: t(PERIODS.fetch(period)),
              current: period == @period,
            }
          end

          def step(day, rel:, label:, icon:)
            a(class: "btn", href: href(@period, day), rel:) do
              i(class: ["fa-solid", icon], aria: { hidden: "true" })
              span(class: "sr-only") { t(label) }
            end
          end

          def steps = STEPS.fetch(@period)
        end
      end
    end
  end
end
