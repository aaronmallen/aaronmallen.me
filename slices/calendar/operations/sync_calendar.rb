# frozen_string_literal: true

require "erb"

module Calendar
  module Operations
    class SyncCalendar < Blog::Operation
      AHEAD_DAYS = 365
      BEHIND_DAYS = 90
      BUSY_ONLY = "freeBusyReader"
      CANCELLED = "cancelled"
      PAGE_SIZE = 2500
      SCOPES = %w[
        https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.calendarlist.readonly
      ].freeze
      WRITERS = %w[owner writer].freeze

      include Deps[
        google: "google.client", calendar_mutations: "repos.calendar_mutations",
        calendar_queries: "repos.calendar_queries",
      ]

      def call(today = Blog::TimeZone.today) = step synced(today - BEHIND_DAYS, today + AHEAD_DAYS)

      private

      def calendar(account, item, token, from, to)
        id = item.fetch("id")

        {
          google_id: id, name: item["summaryOverride"] || item.fetch("summary"), writable: writable?(account, item),
          synced_from: from, **events(account, id, token, from, to),
        }
      end

      def calendars(account, from, to)
        listed = account.pages(google.url(:calendar, "users/me/calendarList"), rows: "items").fetch("items")
        tokens = calendar_queries.sync_tokens(account.id, from)

        listed.reject { it["accessRole"] == BUSY_ONLY }.map { calendar(account, it, tokens[it["id"]], from, to) }
      end

      def details(item)
        {
          title: item["summary"], place: item["location"], meet_url: item["hangoutLink"], notes: item["description"],
          link: item["htmlLink"], attendees: guests(item.fetch("attendees", [])),
          recurring_id: item["recurringEventId"],
        }
      end

      def event(item)
        { google_id: item.fetch("id"), **timing(item.fetch("start"), item.fetch("end")), **details(item) }
      end

      def events(account, id, token, from, to)
        url = google.url(:calendar, "calendars/#{ERB::Util.url_encode(id)}/events")
        found = account.pages(
          url, rows: "items", singleEvents: true, maxResults: PAGE_SIZE, **since(token, from, to),
        )
        cancelled, kept = found.fetch("items").partition { it["status"] == CANCELLED }

        {
          events: kept.map { event(it) }, cancelled: cancelled.map { it.fetch("id") }, full: token.nil?,
          sync_token: found["nextSyncToken"],
        }
      rescue Google::Gone
        raise if token.nil?

        events(account, id, nil, from, to)
      end

      def guests(attendees)
        attendees.reject { it["self"] || it["resource"] }.map { it["displayName"] || it.fetch("email") }
      end

      def last_day(time) = Blog::TimeZone.local_date(time - 1)

      def since(token, from, to)
        return { syncToken: token } if token

        Blog::TimeZone.day_bounds(from, to).map { it.utc.iso8601 }.then { { timeMin: it[0], timeMax: it[1] } }
      end

      def sync(account, from, to)
        Success(calendar_mutations.store(account.id, calendars(account, from, to), to:))
      rescue Google::Error => e
        Failure([:google_calendar_failed, e.message])
      end

      def synced(from, to)
        return Success(0) unless google.configured?

        client = google.loaded
        calendar_mutations.forget_accounts_but(client.holders(*SCOPES, lapsed: true))
        results = client.holders(*SCOPES).map { sync(Google::Account.new(client, it), from, to) }
        results.find(&:failure?) || Success(results.sum(&:value!))
      end

      def timing(start, finish)
        return whole_days(start, finish) if start.key?("date")

        starts_at, ends_at = [start, finish].map { Time.iso8601(it.fetch("dateTime")) }
        starts_on = Blog::TimeZone.local_date(starts_at)

        { starts_on:, ends_on: [starts_on, last_day(ends_at)].max, starts_at:, ends_at: }
      end

      def whole_days(start, finish)
        starts_on = Date.iso8601(start.fetch("date"))

        { starts_on:, ends_on: [starts_on, Date.iso8601(finish.fetch("date")) - 1].max, starts_at: nil, ends_at: nil }
      end

      def writable?(account, item)
        WRITERS.include?(item["accessRole"]) && !account.work?
      end
    end
  end
end
