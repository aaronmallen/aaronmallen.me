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
          prop :values, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            Form(id: id(:form), action: @action, class: "cal-event-form", data: { morph: (true if @morph) }) do
              hidden_fields
              text(:title, t(".title"), value: @values.fetch(:title) { @event&.title }, required: true)
              calendar unless @event
              timing
              text(:place, t(".place"), value: @values.fetch(:place) { @event&.place })
              foot
            end
          end

          private

          def all_day? = @values.key?(:all_day) ? Blog::Types::Checkbox[@values[:all_day]] : @event&.all_day? || false

          def calendar
            Field(label: t(".calendar"), **error_props(:calendar)) do |control|
              select(class: "inp", name: "calendar", **control) { options }
              Hint { t(".read_only") } unless @calendars.all?(&:writable)
            end
          end

          def clock(name, at, fallback)
            @values.fetch(name) do
              time = @event&.public_send(at)

              time ? Blog::TimeZone.local(time).strftime("%H:%M") : fallback
            end
          end

          def date = @values.fetch(:date) { (@event&.starts_on || @day).iso8601 }

          def error_props(name) = { name:, errors: @errors, error: FieldError, scope: id(nil) }

          def field(name, label, **)
            Field(label:, **error_props(name)) { |control| Input(**control, name: name.to_s, **) }
          end

          def foot
            Scope(label: t(".change"), selected: Blog::Types::OptionalText[@values[:scope]]) if @event&.recurring_id
            Button(type: "submit", small: true, variant: :pri) { @event ? t(".save") : t(".add") }
          end

          def hidden_fields
            input(type: "hidden", name: "day", value: @day.iso8601)
            input(type: "hidden", name: "menu", value: Blog::Constants::CHECKED) if @morph
          end

          def id(name) = ["cal-event", @event&.id || "new", ("menu" if @morph), name].compact.join("-")

          def options
            @calendars.select(&:writable).group_by(&:account).each do |account, calendars|
              optgroup(label: account) do
                calendars.each do |calendar|
                  option(value: calendar.id, selected: calendar.id.to_s == @values[:calendar]) { calendar.name }
                end
              end
            end
          end

          def text(name, label, **) = field(name, label, type: "text", **)

          def timing
            div(class: "cal-event-when") do
              field(:date, t(".date"), type: "date", value: date, required: true)
              field(:starts, t(".starts"), type: "time", value: clock(:starts, :starts_at, DEFAULT_STARTS))
              field(:ends, t(".ends"), type: "time", value: clock(:ends, :ends_at, DEFAULT_ENDS))
            end
            Checkbox(label: t(".all_day"), name: "all_day", checked: all_day?)
          end
        end
      end
    end
  end
end
