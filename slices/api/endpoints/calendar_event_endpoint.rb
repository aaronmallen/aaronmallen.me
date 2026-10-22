# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class CalendarEventEndpoint < Endpoint
      CONTRACTS = [::Calendar::Contracts::EventContract].freeze
      CLOCK = "needs a time of day as HH:MM, such as 09:30"
      COMPLAINTS = {
        title: { Blog::Contract::BLANK => "title needs a character that is not a space" },
        date: { Blog::Contract::FORMAT => "date needs a day, such as 2026-01-01" },
        starts: { Blog::Contract::FORMAT => "starts #{CLOCK}, unless all_day is true" },
        ends: {
          Blog::Contract::FORMAT => "ends #{CLOCK}, unless all_day is true",
          ::Calendar::Contracts::EventContract::ENDS_FIRST => "ends comes before starts; pick a later time",
        },
      }.freeze
      GOOGLE_DOWN = "Google did not take the change, so nothing changed; try again soon"
      ID = Helpers::Schema::ID.merge(description: "the event's ID, from list_calendar")
      READ_ONLY = "the calendar is on a work account or one Google lets you only read, so it takes no changes"
      SKIPPED = { starts: [Blog::Contract::SKIPPED] }.freeze
      SCOPE = {
        type: "string",
        enum: [::Calendar::EventOperation::SERIES, "this"],
        description: "this changes one event of a recurring series and all every event in it; this when left out",
      }.freeze
      FIELDS = {
        title: { type: "string", description: "what the event is called" },
        date: { **Helpers::Schema::DAY, description: "the day it starts, as YYYY-MM-DD" },
        all_day: { **Helpers::Schema::BOOLEAN, description: "whether it covers the whole day with no times" },
        starts: { **Helpers::Schema::CLOCK, description: "the time it starts, as HH:MM in #{Blog::TimeZone::NAME}" },
        ends: { **Helpers::Schema::CLOCK, description: "the time it ends, as HH:MM in #{Blog::TimeZone::NAME}" },
        place: { type: "string", description: "where it happens" },
      }.freeze

      include Deps[calendar_queries: "calendar.repos.calendar_queries"]

      private

      def clock(time) = time && Blog::TimeZone.local(time).strftime("%H:%M")

      def fields_of(event)
        {
          title: event.title, date: event.starts_on.iso8601, all_day: event.all_day?,
          starts: clock(event.starts_at), ends: clock(event.ends_at), place: event.place,
        }
      end

      def refused(errors) = rejected(errors.empty? ? SKIPPED : errors, COMPLAINTS)

      def written(result, id, field: :id, noun: "event")
        case result
          in Success(_) then yield
          in Failure(:not_found) then missing(noun, id)
          in Failure(:read_only) then invalid(field => [READ_ONLY])
          in Failure[:invalid, errors] then refused(errors)
          in Failure[:google_failed, _] then Failure(Structs::Refusal.unavailable(GOOGLE_DOWN))
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
