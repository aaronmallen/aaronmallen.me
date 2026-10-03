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
            nav(class: "cal-pager", aria: { label: t(".label") }) do
              step(@month.prev_month, rel: "prev", label: ".previous", icon: "fa-arrow-left")
              a(class: "btn", href: path(:admin_calendar)) { t(".today") } unless showing_today?
              step(@month.next_month, rel: "next", label: ".next", icon: "fa-arrow-right")
            end
          end

          private

          def showing_today? = @month.year == @today.year && @month.month == @today.month

          def step(month, rel:, label:, icon:)
            a(class: "btn", href: path(:admin_calendar, month: month.strftime(MONTH)), rel:) do
              i(class: ["fa-solid", icon], aria: { hidden: "true" })
              span(class: "sr-only") { t(label, month: l(month, format: :month)) }
            end
          end
        end
      end
    end
  end
end
