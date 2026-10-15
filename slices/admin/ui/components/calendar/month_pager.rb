# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class MonthPager < Component
          MONTH = "%Y-%m"

          prop :month, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            SegmentedLinks(
              label: t(".label"),
              items: [
                step(@month.prev_month, rel: "prev", label: ".previous", icon: "fa-chevron-left"),
                { href: path(:admin_calendar), text: t(".today"), current: showing_today? },
                step(@month.next_month, rel: "next", label: ".next", icon: "fa-chevron-right"),
              ],
            )
          end

          private

          def showing_today? = @month.year == @today.year && @month.month == @today.month

          def step(month, rel:, label:, icon:)
            {
              href: path(:admin_calendar, month: month.strftime(MONTH)),
              text: t(label, month: l(month, format: :month)),
              icon:,
              rel:,
            }
          end
        end
      end
    end
  end
end
