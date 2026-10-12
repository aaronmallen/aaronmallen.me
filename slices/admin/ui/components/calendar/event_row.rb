# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class EventRow < Component
          MEET = "fa-solid fa-video"

          prop :event, Blog::Types::Instance(ROM::Struct)
          prop :tone, Blog::Types::String
          prop :day, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            div(class: "cal-event", style: Tone.style(@tone), data:) do
              span(class: "cal-event-time") { @event.all_day? ? t(".all_day") : clock(@event.starts_at) }
              details(class: "cal-event-body") do
                head
                more
              end
              join
              move
            end
          end

          private

          def attendees
            p(class: "li-sub") { IconLabel(icon: "fa-solid fa-user-group") { @event.attendees.join(", ") } }
          end

          def changes
            return p(class: "li-sub") { t(".read_only") } unless @event.calendar.writable

            details(class: "cal-event-edit") do
              summary(class: "bt sm gh") { IconLabel(icon: "fa-regular fa-pen-to-square") { t(".edit") } }
              EventForm(action: path(:admin_update_calendar_event, id: @event.id), day: @day, event: @event)
            end
            delete_form
          end

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def data
            { calendar_item: "event-#{@event.id}",
              menu: path(:admin_calendar_event_menu, id: @event.id, day: @day.iso8601) }
          end

          def delete_form
            Form(
              action: path(:admin_delete_calendar_event, id: @event.id), class: "cal-event-delete",
              data: { confirm: t(".confirm_delete", title:) },
            ) do
              input(type: "hidden", name: "day", value: @day.iso8601)
              Scope(label: t(".delete_which")) if @event.recurring_id
              Button(type: "submit", small: true, variant: :warn, icon: "fa-regular fa-trash-can") { t(".delete") }
            end
          end

          def head
            summary(class: "cal-event-title") do
              span(class: "cal-event-name") { title }
              span(class: "li-sub cal-event-meta") { meta }
            end
          end

          def join
            return unless @event.meet_url

            Button(
              href: @event.meet_url, small: true, variant: :gh, icon: MEET, target: "_blank", rel: "noopener",
              label: t(".join", title:),
            )
          end

          def link(href, icon, text)
            Button(href:, small: true, variant: :gh, icon:, target: "_blank", rel: "noopener") { text }
          end

          def links
            div(class: "cal-event-links") do
              link(@event.meet_url, MEET, t(".meet")) if @event.meet_url
              link(@event.link, "fa-solid fa-arrow-up-right-from-square", t(".google")) if @event.link
            end
          end

          def meta
            span(class: "cal-event-calendar") { @event.calendar.name }
            span { "#{clock(@event.starts_at)}–#{clock(@event.ends_at)}" } unless @event.all_day?
            span { t(".until", date: l(@event.ends_on, format: :short)) } if @event.ends_on > @event.starts_on
            span { IconLabel(icon: "fa-solid fa-location-dot") { @event.place } } if @event.place
          end

          def more
            div(class: "cal-event-more") do
              p(class: "cal-event-notes") { @event.notes } if @event.notes
              attendees if @event.attendees.any?
              p(class: "li-sub") { @event.calendar.account }
              links
              changes
            end
          end

          def move
            MoveForm(kind: :event, id: @event.id, title:, date: @day, today: @today) if @event.calendar.writable
          end

          def title = @event.title || t(".untitled")
        end
      end
    end
  end
end
