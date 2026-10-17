# frozen_string_literal: true

require "erb"

module Calendar
  module Helpers
    module GoogleEvent
      CLOCK = /\A(\d{2}):(\d{2})\z/

      module_function

      def at(date, clock)
        hour, minute = CLOCK.match(clock).captures.map(&:to_i)

        { date: nil, dateTime: Blog::TimeZone.local_time(date.year, date.month, date.day, hour, minute).iso8601,
          timeZone: Blog::TimeZone::NAME }
      end

      def body(fields, date:, span: 0)
        { summary: fields[:title], location: fields[:place], **timing(fields, date, span) }
      end

      def first_day(item)
        start = item.fetch("start")

        start["date"] ? Date.iso8601(start["date"]) : Blog::TimeZone.today(Time.iso8601(start.fetch("dateTime")))
      end

      def timing(fields, date, span)
        return { start: at(date, fields[:starts]), end: at(date + span, fields[:ends]) } unless fields[:all_day]

        { start: whole(date), end: whole(date + span + 1) }
      end

      def url(calendar, id = nil)
        events = "#{Operations::SyncCalendar::API}/calendars/#{ERB::Util.url_encode(calendar.google_id)}/events"

        id ? "#{events}/#{ERB::Util.url_encode(id)}" : events
      end

      def whole(date) = { date: date.iso8601, dateTime: nil, timeZone: nil }
    end
  end
end
