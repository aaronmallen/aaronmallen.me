# frozen_string_literal: true

require "erb"

module Calendar
  module Operations
    class SyncCalendar < Blog::Operation
      AHEAD_DAYS = 365
      API = "https://www.googleapis.com/calendar/v3"
      BEHIND_DAYS = 90
      BUSY_ONLY = "freeBusyReader"
      PAGE_SIZE = 2500
      SCOPES = %w[
        https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.calendarlist.readonly
      ].freeze
      WRITERS = %w[owner writer].freeze

      include Deps[google: "google.google.client", calendar_mutations: "repos.calendar_mutations"]

      def call(today = Blog::TimeZone.today) = step synced(today - BEHIND_DAYS, today + AHEAD_DAYS)

      private

      def calendar(account, item, from, to)
        {
          google_id: item.fetch("id"), name: item["summaryOverride"] || item.fetch("summary"),
          writable: WRITERS.include?(item["accessRole"]), events: events(account, item.fetch("id"), from, to),
        }
      end

      def calendars(account, from, to)
        listed = pages(account, "#{API}/users/me/calendarList")

        listed.reject { it["accessRole"] == BUSY_ONLY }.map { calendar(account, it, from, to) }
      end

      def details(item)
        {
          title: item["summary"], place: item["location"], meet_url: item["hangoutLink"], notes: item["description"],
          link: item["htmlLink"], attendees: guests(item.fetch("attendees", [])),
        }
      end

      def event(item)
        { google_id: item.fetch("id"), **timing(item.fetch("start"), item.fetch("end")), **details(item) }
      end

      def events(account, id, from, to)
        bounds = Blog::TimeZone.day_bounds(from, to).map { it.utc.iso8601 }
        url = "#{API}/calendars/#{ERB::Util.url_encode(id)}/events"

        pages(account, url, singleEvents: true, timeMin: bounds[0], timeMax: bounds[1], maxResults: PAGE_SIZE)
          .map { event(it) }
      end

      def guests(attendees)
        attendees.reject { it["self"] || it["resource"] }.map { it["displayName"] || it.fetch("email") }
      end

      def last_day(time) = Blog::TimeZone.today(time - 1)

      def pages(account, url, **params)
        page = google.get(url, account:, **params)
        token = page["nextPageToken"].to_s
        rows = page.fetch("items", [])

        token.empty? ? rows : rows + pages(account, url, **params, pageToken: token)
      end

      def sync(account, from, to)
        Success(calendar_mutations.store(account, calendars(account, from, to), from:, to:))
      rescue Google::Error => e
        Failure([:google_calendar_failed, e.message])
      end

      def synced(from, to)
        accounts = google.holders(*SCOPES)
        return Success(0) if accounts.nil?

        calendar_mutations.forget_accounts_but(accounts)
        results = accounts.map { sync(it, from, to) }
        results.find(&:failure?) || Success(results.sum(&:value!))
      end

      def timing(start, finish)
        return whole_days(start, finish) if start.key?("date")

        starts_at, ends_at = [start, finish].map { Time.iso8601(it.fetch("dateTime")) }
        starts_on = Blog::TimeZone.today(starts_at)

        { starts_on:, ends_on: [starts_on, last_day(ends_at)].max, starts_at:, ends_at: }
      end

      def whole_days(start, finish)
        starts_on = Date.iso8601(start.fetch("date"))

        { starts_on:, ends_on: [starts_on, Date.iso8601(finish.fetch("date")) - 1].max, starts_at: nil, ends_at: nil }
      end
    end
  end
end
