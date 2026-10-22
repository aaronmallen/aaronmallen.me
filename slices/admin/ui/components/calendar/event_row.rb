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
          prop :refused, Blog::Types::Hash.optional, default: nil

          def view_template
            div(class: "cal-event", style: Tone.style(@tone), data:) do
              span(class: "cal-event-time") { @event.all_day? ? t(".all_day") : clock(@event.starts_at) }
              details(class: "cal-event-body", open: refused?) do
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

            details(class: "cal-event-edit", open: refused?) do
              Button(summary: true, small: true, variant: :gh) do
                IconLabel(icon: :edit) do
                  t(".edit")
                end
              end
              EventForm(action: path(:admin_update_calendar_event, id: @event.id), day: @day, event: @event, **form)
            end
            delete_form
          end

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def data
            { calendar_item: "event-#{@event.id}",
              menu: path(:admin_calendar_event_menu, id: @event.id, day: @day.iso8601) }
          end

          def delete_form
            DeleteForm(
              action: path(:admin_delete_calendar_event, id: @event.id), class: "cal-event-delete",
              confirm: t(".confirm_delete", title:), label: t(".delete"),
            ) do
              input(type: "hidden", name: "day", value: @day.iso8601)
              Scope(label: t(".delete_which")) if @event.recurring_id
            end
          end

          def form
            return Blog::Constants::EMPTY_HASH unless @refused

            { morph: @refused[:menu], values: @refused[:values], errors: @refused[:errors] }
          end

          def head
            summary(class: "cal-event-title") do
              span(class: "cal-event-name") { title }
              EventMeta(event: @event)
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
              link(@event.link, :outbound, t(".google")) if @event.link
            end
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

          def refused? = !@refused.nil?

          def title = @event.title || t(".untitled")
        end
      end
    end
  end
end
