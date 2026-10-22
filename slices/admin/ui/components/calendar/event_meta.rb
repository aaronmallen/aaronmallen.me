# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class EventMeta < Component
          prop :event, Blog::Types::Instance(ROM::Struct)

          def view_template
            span(class: "li-sub cal-event-meta") do
              span(class: "cal-event-calendar") { @event.calendar.name }
              span { "#{clock(@event.starts_at)}–#{clock(@event.ends_at)}" } unless @event.all_day?
              span { t(".until", date: l(@event.ends_on, format: :short)) } if @event.ends_on > @event.starts_on
              span { IconLabel(icon: "fa-solid fa-location-dot") { @event.place } } if @event.place
            end
          end

          private

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)
        end
      end
    end
  end
end
