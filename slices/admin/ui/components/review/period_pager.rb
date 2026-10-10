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
          prop :keep, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            SegmentedLinks(label: t(".periods"), items: PERIODS.keys.map { period_link(it) })
            nav(class: "seg", aria: { label: t(steps[:label]) }) { arrows }
          end

          private

          def arrows
            step(earlier, rel: "prev", label: steps[:previous], icon: "fa-chevron-left")
            current
            step(later, rel: "next", label: steps[:next], icon: "fa-chevron-right", disabled: current?)
          end

          def current
            return span(class: "seg-option current", aria: { current: "page" }) { t(steps[:current]) } if current?

            a(class: "seg-option", href: href(@period)) { t(steps[:current]) }
          end

          def current? = (@from..@to).cover?(@today)

          def earlier = month? ? @on.prev_month : @on - WEEK

          def href(period, day = nil)
            path(:admin_review, **{ period: (period if period == MONTH), day: day&.iso8601 }.compact, **@keep)
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

          def step(day, rel:, label:, icon:, disabled: false)
            inner = proc do
              Icon(["fa-solid", icon])
              span(class: "sr-only") { t(label) }
            end
            return span(class: "seg-option", aria: { disabled: true }, &inner) if disabled

            a(class: "seg-option", href: href(@period, day), rel:, &inner)
          end

          def steps = STEPS.fetch(@period)
        end
      end
    end
  end
end
