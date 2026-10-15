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
            SegmentedLinks(
              label: t(steps[:label]),
              items: [
                step(earlier, rel: "prev", label: steps[:previous], icon: "fa-chevron-left"),
                current,
                step(later, rel: "next", label: steps[:next], icon: "fa-chevron-right", disabled: current?),
              ],
            )
          end

          private

          def current
            return { text: t(steps[:current]), current: true } if current?

            { href: href(@period), text: t(steps[:current]) }
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
            { href: href(@period, day), text: t(label), icon:, rel:, disabled: }
          end

          def steps = STEPS.fetch(@period)
        end
      end
    end
  end
end
