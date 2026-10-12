# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class EventForm < Component
          DEFAULT_ENDS = "10:30"
          DEFAULT_STARTS = "10:00"

          prop :action, Blog::Types::String
          prop :day, Blog::Types::Date
          prop :calendars, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct)), default: Blog::Constants::EMPTY_ARRAY
          prop :event, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop :morph, Blog::Types::Bool, default: false

          def view_template
            Form(action: @action, class: "cal-event-form", data: { morph: (true if @morph) }) do
              input(type: "hidden", name: "day", value: @day.iso8601)
              text(:title, t(".title"), value: @event&.title, required: true)
              calendar unless @event
              timing
              text(:place, t(".place"), value: @event&.place)
              foot
            end
          end

          private

          def calendar
            Field(label: t(".calendar"), id: id(:calendar)) do |control|
              select(class: "inp", name: "calendar", **control) { options }
              Hint { t(".read_only") } unless @calendars.all?(&:writable)
            end
          end

          def clock(at, fallback)
            time = @event&.public_send(at)

            time ? Blog::TimeZone.local(time).strftime("%H:%M") : fallback
          end

          def date = @event&.starts_on || @day

          def field(name, label, **)
            Field(label:, id: id(name)) { |control| Input(**control, name: name.to_s, **) }
          end

          def foot
            Scope(label: t(".change")) if @event&.recurring_id
            Button(type: "submit", small: true, variant: :pri) { @event ? t(".save") : t(".add") }
          end

          def id(name) = ["cal-event", @event&.id || "new", ("menu" if @morph), name].compact.join("-")

          def options
            @calendars.select(&:writable).group_by(&:account).each do |account, calendars|
              optgroup(label: account) { calendars.each { |calendar| option(value: calendar.id) { calendar.name } } }
            end
          end

          def text(name, label, **) = field(name, label, type: "text", **)

          def timing
            div(class: "cal-event-when") do
              field(:date, t(".date"), type: "date", value: date.iso8601, required: true)
              field(:starts, t(".starts"), type: "time", value: clock(:starts_at, DEFAULT_STARTS))
              field(:ends, t(".ends"), type: "time", value: clock(:ends_at, DEFAULT_ENDS))
            end
            Checkbox(label: t(".all_day"), name: "all_day", checked: @event&.all_day? || false)
          end
        end
      end
    end
  end
end
