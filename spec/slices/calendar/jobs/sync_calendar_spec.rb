# frozen_string_literal: true

RSpec.describe Calendar::Jobs::SyncCalendar, :frozen_clock do
  let(:scopes) { Calendar::Operations::SyncCalendar::SCOPES }
  let(:today) { Blog::TimeZone.today }

  def all_day(id, first, last, **)
    { id:, summary: "On-call", start: { date: first.iso8601 }, end: { date: (last + 1).iso8601 }, ** }
  end

  def api = Calendar::Operations::SyncCalendar::API

  def calendars = queries.listed

  def connect(account, token, **) = connect_google(account_id: account, scopes:, token:, **)

  def events = queries.events_between(from: today - 1000, to: today + 1000)

  def failure = Record::Slice["repos.sync_state_queries"].failure(sync)

  def google_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def local(date, hour) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour)

  def queries = Calendar::Slice["repos.calendar_queries"]

  def run = described_class.new.perform

  def stub_calendars(token, *items)
    stub_request(:get, "#{api}/users/me/calendarList").with(headers: { "Authorization" => "Bearer #{token}" })
                                                      .to_return(google_json(items:))
  end

  def stub_events(calendar, *items, **body)
    stub_request(:get, %r{\A#{api}/calendars/#{Regexp.escape(calendar)}/events\?})
      .to_return(google_json(items:, **body))
  end

  def sync = Blog::Types::SyncName["calendar"]

  def timed(id, start, finish, **)
    { id:, summary: "Standup", start: { dateTime: start.iso8601 }, end: { dateTime: finish.iso8601 }, ** }
  end

  describe "with two connected accounts" do
    let(:mine) { [] }
    let(:theirs) { [] }

    def coffee
      timed(
        "coffee_20261011", local(today, 9), local(today, 10),
        location: "Lakeview", hangoutLink: "https://meet.google.com/abc", description: "Bring notes",
        htmlLink: "https://calendar.google.com/event?eid=1",
        attendees: [
          { email: "me@example.com", self: true }, { email: "dana@example.com", displayName: "Dana" },
          { email: "sam@example.com" }, { email: "room@resource.calendar.google.com", resource: true },
        ],
      )
    end

    def stored_coffee
      {
        google_id: "coffee_20261011", title: "Standup", starts_on: today, ends_on: today,
        starts_at: local(today, 9), ends_at: local(today, 10), place: "Lakeview",
        meet_url: "https://meet.google.com/abc", attendees: ["Dana", "sam@example.com"], notes: "Bring notes",
        link: "https://calendar.google.com/event?eid=1", recurring_id: nil,
      }
    end

    def window
      hash_including(
        "singleEvents" => "true",
        "timeMin" => Blog::TimeZone.day_start(today - 90).utc.iso8601,
        "timeMax" => Blog::TimeZone.day_start(today + 366).utc.iso8601,
      )
    end

    before do
      connect("me@example.com", "ya29.me")
      connect("work@example.com", "ya29.work", work: true)
      stub_calendars("ya29.me", { id: "me@example.com", summary: "Aaron", accessRole: "owner" })
      stub_calendars(
        "ya29.work",
        { id: "work@example.com", summary: "Work", summaryOverride: "Day job", accessRole: "reader" },
        { id: "busy@example.com", summary: "Busy", accessRole: "freeBusyReader" },
      )
      stub_events("me@example.com", *mine)
      stub_events("work@example.com", *theirs)
    end

    it "keeps each account's calendars, naming them as I do and noting which take writes" do
      run

      expect(calendars.map { it.to_h.values_at(:account, :name, :writable) })
        .to eq([["me@example.com", "Aaron", true], ["work@example.com", "Day job", false]])
    end

    it "takes no writes on a work account, even where Google grants them" do
      stub_calendars("ya29.work", { id: "work@example.com", summary: "Work", accessRole: "owner" })
      run

      expect(calendars.to_h { [it.account, it.writable] }).to eq("me@example.com" => true, "work@example.com" => false)
    end

    it "asks Google for each instance of a recurring event across the window" do
      run

      expect(a_request(:get, %r{/calendars/me@example\.com/events}).with(query: window)).to have_been_made
    end

    describe "with a timed event" do
      let(:mine) { [coffee] }

      it "stores it with its place, Meet link, guests, notes and link" do
        run

        expect(events.map { it.to_h.except(:id, :calendar_id, :calendar, :created_at, :updated_at) })
          .to eq([stored_coffee])
      end
    end

    describe "with an event that has not changed since the last run", :commits do
      let(:mine) { [coffee] }

      it "sends the admin no notice" do
        run
        allow(Time).to receive(:now).and_return(now + 60)

        expect(admin_notice { run }).to be_nil
      end
    end

    describe "with an instance of a recurring event" do
      let(:mine) { [timed("standup_20261011", local(today, 9), local(today, 10), recurringEventId: "standup")] }

      it "keeps the series it belongs to" do
        run

        expect(events.map(&:recurring_id)).to eq(["standup"])
      end
    end

    describe "with an all-day event" do
      let(:theirs) { [all_day("oncall", today + 1, today + 7)] }

      it "stores it through its last day, with no times" do
        run

        expect(events.map { it.to_h.slice(:starts_on, :ends_on, :starts_at, :ends_at) })
          .to eq([{ starts_on: today + 1, ends_on: today + 7, starts_at: nil, ends_at: nil }])
      end
    end

    describe "with an event that runs to midnight" do
      let(:mine) { [timed("late", local(today, 22), local(today + 1, 0))] }

      it "ends it on the day it started" do
        run

        expect(events.map { [it.starts_on, it.ends_on] }).to eq([[today, today]])
      end
    end

    describe "with events on two pages" do
      before do
        stub_events("me@example.com", timed("a", local(today, 9), local(today, 10)), nextPageToken: "next")
        stub_request(:get, %r{/calendars/me@example\.com/events\?.*pageToken=next})
          .to_return(google_json(items: [timed("b", local(today, 11), local(today, 12))]))
      end

      it "reads every page" do
        run

        expect(events.map(&:google_id)).to eq(%w[a b])
      end
    end

    describe "when it runs again" do
      let(:mine) do
        [timed("kept", local(today, 9), local(today, 10)), timed("gone", local(today, 11), local(today, 12))]
      end

      before do
        run
        Calendar::Slice["repos.calendar_mutations"].show([])
      end

      it "updates what changed, drops what Google dropped and keeps each row's id" do
        kept = events.find { it.google_id == "kept" }.id
        stub_events("me@example.com", timed("kept", local(today, 9), local(today, 10), summary: "Moved standup"))
        run

        expect(events.map { [it.id, it.title] }).to eq([[kept, "Moved standup"]])
      end

      it "keeps a calendar I hid hidden" do
        run

        expect(calendars.map(&:hidden)).to all(be(true))
      end

      it "keeps an event older than the window it reads" do
        old = create(:calendar_event, calendar_id: calendars.first.id, starts_on: today - 200, ends_on: today - 200)
        run

        expect(events.map(&:id)).to include(old.id)
      end

      it "drops a calendar the account no longer lists, with its events" do
        stub_calendars("ya29.me")
        run

        expect([calendars.map(&:account), events]).to eq([["work@example.com"], []])
      end

      it "drops the calendars of an account that no longer grants Calendar" do
        Services::Slice["relations.service_connections"].where(account_id: "me@example.com").delete
        run

        expect(calendars.map(&:account)).to eq(["work@example.com"])
      end
    end

    describe "when one account fails" do
      before do
        stub_request(:get, "#{api}/users/me/calendarList").with(headers: { "Authorization" => "Bearer ya29.work" })
                                                          .to_return(status: 503)
        run
      end

      it "records the failure" do
        expect(failure).to include(reason: "google_calendar_failed", message: "Google answered 503")
      end

      it "still syncs the others" do
        expect(calendars.map(&:account)).to eq(["me@example.com"])
      end
    end
  end

  it "leaves an account without Calendar alone", :aggregate_failures do
    connect_google(account_id: "health@example.com", token: "ya29.health")
    run

    expect(a_request(:any, /googleapis\.com/)).not_to have_been_made
    expect(calendars).to be_empty
  end

  describe "with a revoked account" do
    before do
      connect("me@example.com", "ya29.me")
      create(:calendar, account: "me@example.com")
      Services::Slice["relations.service_connections"].update(revoked_at: Time.now)
      run
    end

    it "says it needs a reconnect" do
      expect(failure).to include(reason: "google_calendar_failed", message: "me@example.com needs a reconnect")
    end

    it("keeps its calendars") { expect(calendars.size).to eq(1) }
  end

  describe "after a run that failed" do
    before do
      Record::Slice["repos.sync_state_mutations"].record_failure(sync, "google_calendar_failed")
      connect("me@example.com", "ya29.me")
      stub_calendars("ya29.me")
      run
    end

    it("clears the failure once a run succeeds") { expect(failure).to be_nil }
  end
end
