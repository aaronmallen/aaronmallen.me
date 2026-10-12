# frozen_string_literal: true

module API
  module Serializers
    class CalendarEvent < Serializer
      TEXT = Helpers::Schema.nullable(Helpers::Schema::STRING)

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: TEXT,
          calendar: Helpers::Schema.object(
            {
              id: Helpers::Schema::INTEGER,
              name: Helpers::Schema::STRING,
              account: { type: "string", description: "the Google account the calendar belongs to" },
            },
          ),
          all_day: { type: "boolean", description: "whether the event spans whole days with no times" },
          starts_on: Helpers::Schema::DAY,
          ends_on: { **Helpers::Schema::DAY, description: "the last day the event covers" },
          starts_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          ends_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          place: TEXT,
          meet_url: TEXT,
          attendees: { type: "array", items: Helpers::Schema::STRING, description: "everyone invited but you" },
          notes: TEXT,
          link: TEXT,
        },
      ).freeze

      schema_attributes

      stamps :starts_at, :ends_at

      attribute :all_day, &:all_day?

      def calendar(event) = event.calendar.to_h.slice(:id, :name, :account)

      def ends_on(event) = day(event.ends_on)

      def starts_on(event) = day(event.starts_on)
    end
  end
end
