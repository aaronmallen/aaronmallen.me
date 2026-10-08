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
            nav(class: "seg", aria: { label: t(".label") }) do
              step(@month.prev_month, rel: "prev", label: ".previous", icon: "fa-chevron-left")
              a(class: ["seg-option", ("current" if showing_today?)], href: path(:admin_calendar)) { t(".today") }
              step(@month.next_month, rel: "next", label: ".next", icon: "fa-chevron-right")
            end
          end

          private

          def showing_today? = @month.year == @today.year && @month.month == @today.month

          def step(month, rel:, label:, icon:)
            a(class: "seg-option", href: path(:admin_calendar, month: month.strftime(MONTH)), rel:) do
              Icon(["fa-solid", icon])
              span(class: "sr-only") { t(label, month: l(month, format: :month)) }
            end
          end
        end
      end
    end
  end
end
