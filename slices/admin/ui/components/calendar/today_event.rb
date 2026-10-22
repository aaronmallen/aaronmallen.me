# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class TodayEvent < Component
          MEET = EventRow::MEET
          ORIGIN = Blog::Types::TaskOrigin["today"]
          PREP = "fa-solid fa-square-check"
          STATES = %w[now next past].freeze

          prop :event, Blog::Types::Instance(ROM::Struct)
          prop :tone, Blog::Types::String
          prop :state, Blog::Types::String.enum(*STATES).optional, default: nil
          prop :soon, Blog::Types::String.optional, default: nil

          def view_template
            div(class: "cal-event today-event", style: Tone.style(@tone), data:) do
              span(class: "cal-event-time") { @event.all_day? ? t(".all_day") : clock(@event.starts_at) }
              details(class: "cal-event-body") do
                head
                more
              end
              join
            end
          end

          private

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def data
            return { today_event: "" } if @event.all_day?

            { today_event: "", starts: @event.starts_at.iso8601, ends: @event.ends_at.iso8601, state: @state }
          end

          def guests
            p(class: "li-sub") { IconLabel(icon: "fa-solid fa-user-group") { @event.attendees.join(", ") } }
          end

          def head
            summary(class: "cal-event-title") do
              span(class: "today-event-head") do
                span(class: "cal-event-name") { title }
                timing unless @event.all_day?
              end
              EventMeta(event: @event)
            end
          end

          def join
            return unless @event.meet_url

            Button(
              href: @event.meet_url, small: true, variant: :gh, icon: MEET, target: "_blank", rel: "noopener",
              label: t(".join", title:), class: "today-event-join",
            )
          end

          def link(href, icon, text)
            Button(href:, small: true, variant: :gh, icon:, target: "_blank", rel: "noopener") { text }
          end

          def links
            div(class: "cal-event-links") do
              link(@event.meet_url, MEET, t(".meet")) if @event.meet_url
              prep
              link(@event.link, :outbound, t(".google")) if @event.link
            end
          end

          def more
            div(class: "cal-event-more") do
              p(class: "cal-event-notes") { @event.notes } if @event.notes
              guests if @event.attendees.any?
              p(class: "li-sub") { @event.calendar.account }
              links
            end
          end

          def prep
            Button(
              href: path(:admin_new_task, origin: ORIGIN, title:), small: true, variant: :gh, icon: PREP,
              **mix(Dialog.opens(Tasks::CreateDialog::ID), data: { prep_title: title }),
            ) { t(".prep") }
          end

          def timing
            span(data: { today_now: "" }, hidden: @state != "now") { Pill(color: :blue) { t(".now") } }
            span(class: "today-event-soon", data: { today_soon: "" }) { @soon }
          end

          def title = @event.title || t(".untitled")
        end
      end
    end
  end
end
