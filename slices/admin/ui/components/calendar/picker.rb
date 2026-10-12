# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Picker < Component
          prop :calendars, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :tones, Blog::Types::Hash
          prop :day, Blog::Types::Date

          def view_template
            return if @calendars.empty?

            SavedViewMenu(label: t(".label", shown: @calendars.count { !it.hidden }, total: @calendars.size),
                          icon: "fa-brands fa-google") do
              Form(action: path(:admin_show_calendars), class: "cal-picker") do
                input(type: "hidden", name: "day", value: @day.iso8601)
                @calendars.group_by(&:account).each { account(*it) }
                foot
              end
            end
          end

          private

          def account(name, calendars)
            fieldset(class: "cal-picker-account") do
              legend(class: "cal-group-title") { name }
              calendars.each { calendar(it) }
            end
          end

          def calendar(calendar)
            label(class: "cal-picker-row", style: Tone.style(@tones.fetch(calendar.id))) do
              input(type: "checkbox", name: "shown[]", value: calendar.id, checked: !calendar.hidden)
              span(class: "cal-picker-name") { calendar.name }
              span(class: "cal-picker-note") { t(".read_only") } unless calendar.writable
            end
          end

          def foot
            div(class: "cal-picker-foot") do
              Button(type: "submit", small: true, variant: :pri) { t(".save") }
              Button(type: "submit", small: true, variant: :gh, name: "preset", value: "all") { t(".all") }
              Button(type: "submit", small: true, variant: :gh, name: "preset", value: "work") { t(".work") }
            end
          end
        end
      end
    end
  end
end
