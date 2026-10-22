# frozen_string_literal: true

RSpec.describe "MCP calendar tools", :frozen_clock, type: :request do
  let(:day) { Blog::TimeZone.today + 3 }
  let(:mine) { create(:calendar, account: "me@example.com", google_id: "me@example.com", name: "Aaron") }
  let(:work) { create(:calendar, account: "work@example.com", google_id: "work@example.com", name: "Work") }

  def event(calendar = mine, **)
    times = { starts_at: at(day, 9), ends_at: at(day, 9, 30) }

    create(:calendar_event, calendar_id: calendar.id, title: "Standup", starts_on: day, ends_on: day, **times, **)
  end

  def events_url = "#{Calendar::Operations::SyncCalendar::API}/calendars/me%40example.com/events"

  def google_calls = a_request(:any, %r{googleapis\.com/calendar})

  def google_json(body = {}) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def stored(record) = Calendar::Slice["repos.calendar_queries"].event(record.id)

  def stub_series
    stub_request(:get, "#{events_url}/standup")
      .to_return(google_json(start: { dateTime: at(day - 30, 9).iso8601, timeZone: Blog::TimeZone::NAME }))
  end

  def timed(date, starts, ends)
    {
      start: { date: nil, dateTime: at(date, *starts).iso8601, timeZone: Blog::TimeZone::NAME },
      end: { date: nil, dateTime: at(date, *ends).iso8601, timeZone: Blog::TimeZone::NAME },
    }
  end

  before do
    scopes = Calendar::Operations::SyncCalendar::SCOPES
    connect_google(account_id: "me@example.com", scopes:, token: "ya29.me")
    connect_google(account_id: "work@example.com", scopes:, token: "ya29.work", work: true)
    stub_request(:any, %r{googleapis\.com/calendar}).to_return(google_json)
  end

  describe "create_event" do
    def create_event(calendar, **)
      fields = { title: "Lunch", date: day.iso8601, starts: "12:00", ends: "13:00" }
      mcp_call("create_event", calendar_id: calendar.id, **fields, **)
    end

    it "writes the event to Google and queues the sync", :aggregate_failures do
      create_event(mine, place: "Sawada")

      expect(a_request(:post, events_url).with(body: { summary: "Lunch", location: "Sawada", **timed(day, 12, 13) }))
        .to have_been_made
      expect([mcp_content, Calendar::Jobs::SyncCalendar.jobs.size])
        .to eq([{ "calendar_id" => mine.id, "created" => true }, 1])
    end

    it "makes an all-day event with no times" do
      mcp_call("create_event", calendar_id: mine.id, title: "Trip", date: day.iso8601, all_day: true)

      whole = { start: { date: day.iso8601, dateTime: nil, timeZone: nil },
                end: { date: (day + 1).iso8601, dateTime: nil, timeZone: nil } }

      expect(a_request(:post, events_url).with(body: hash_including(whole))).to have_been_made
    end

    it "refuses a calendar on a work account", :aggregate_failures do
      create_event(work)

      expect(google_calls).not_to have_been_made
      expect([mcp_refused?, mcp_message]).to eq([true, API::Endpoints::CalendarEventEndpoint::READ_ONLY])
    end

    it "names an end before the start", :aggregate_failures do
      create_event(mine, ends: "11:00")

      expect(google_calls).not_to have_been_made
      expect(mcp_message).to eq("ends: ends comes before starts; pick a later time")
    end

    it "names a calendar it does not know" do
      mcp_call("create_event", calendar_id: 999_999, title: "Lunch", date: day.iso8601, all_day: true)

      expect(mcp_message).to eq("no calendar has the ID 999999")
    end
  end

  describe "edit_event" do
    it "keeps every field left out", :aggregate_failures do
      standup = event(google_id: "abc", place: "Room 2")
      mcp_call("edit_event", id: standup.id, title: "Retro")

      expect(a_request(:patch, "#{events_url}/abc")
        .with(body: { summary: "Retro", location: "Room 2", **timed(day, 9, [9, 30]) })).to have_been_made
      expect(mcp_content).to eq("id" => standup.id, "saved" => true)
    end

    it "changes only this event of a series", :aggregate_failures do
      standup = event(google_id: "standup_1", recurring_id: "standup")
      mcp_call("edit_event", id: standup.id, title: "Retro", scope: "this")

      expect(a_request(:patch, "#{events_url}/standup_1")).to have_been_made
      expect(a_request(:patch, "#{events_url}/standup")).not_to have_been_made
    end

    it "changes the whole series when asked" do
      stub_series
      standup = event(google_id: "standup_1", recurring_id: "standup")
      mcp_call("edit_event", id: standup.id, title: "Retro", scope: "all")

      expect(a_request(:patch, "#{events_url}/standup").with(body: hash_including(summary: "Retro")))
        .to have_been_made
    end

    it "refuses an event on a work calendar", :aggregate_failures do
      mcp_call("edit_event", id: event(work).id, title: "Retro")

      expect(google_calls).not_to have_been_made
      expect(mcp_refused?).to be(true)
    end
  end

  describe "move_event" do
    it "moves the event in Google and the mirror", :aggregate_failures do
      standup = event(google_id: "abc")
      mcp_call("move_event", id: standup.id, to: (day + 2).iso8601)

      expect(a_request(:patch, "#{events_url}/abc").with(body: timed(day + 2, 9, [9, 30]))).to have_been_made
      expect([stored(standup).starts_on, mcp_content])
        .to eq([day + 2, { "id" => standup.id, "date" => (day + 2).iso8601 }])
    end

    it "moves only this event of a series by default" do
      mcp_call("move_event", id: event(google_id: "standup_1", recurring_id: "standup").id, to: (day + 1).iso8601)

      expect(a_request(:any, "#{events_url}/standup")).not_to have_been_made
    end

    it "moves the whole series by as many days when asked" do
      stub_series
      standup = event(google_id: "standup_1", recurring_id: "standup")
      mcp_call("move_event", id: standup.id, to: (day + 1).iso8601, scope: "all")

      expect(a_request(:patch, "#{events_url}/standup").with(body: hash_including(timed(day - 29, 9, [9, 30]))))
        .to have_been_made
    end

    it "refuses a day before today", :aggregate_failures do
      mcp_call("move_event", id: event.id, to: (Blog::TimeZone.today - 1).iso8601)

      expect(google_calls).not_to have_been_made
      expect(mcp_message).to eq(API::Endpoints::MoveEvent::PAST)
    end

    it "refuses an event on a work calendar" do
      mcp_call("move_event", id: event(work).id, to: (day + 1).iso8601)

      expect(google_calls).not_to have_been_made
    end
  end

  describe "delete_event" do
    it "deletes the event from Google", :aggregate_failures do
      standup = event(google_id: "abc")
      mcp_call("delete_event", id: standup.id)

      expect(a_request(:delete, "#{events_url}/abc")).to have_been_made
      expect(mcp_content).to eq("id" => standup.id, "deleted" => true)
    end

    it "deletes the whole series when asked" do
      mcp_call("delete_event", id: event(google_id: "standup_1", recurring_id: "standup").id, scope: "all")

      expect(a_request(:delete, "#{events_url}/standup")).to have_been_made
    end

    it "refuses an event on a work calendar" do
      mcp_call("delete_event", id: event(work).id)

      expect(google_calls).not_to have_been_made
    end

    it "says when Google refuses it" do
      stub_request(:delete, "#{events_url}/abc").to_return(status: 403, **google_json)
      mcp_call("delete_event", id: event(google_id: "abc").id)

      expect(mcp_message).to eq(API::Endpoints::CalendarEventEndpoint::GOOGLE_DOWN)
    end
  end

  describe "with write but not delete" do
    def mcp_scopes = %w[read write]

    it "refuses delete_event, naming delete", :aggregate_failures do
      mcp_rpc("tools/call", { name: "delete_event", arguments: { id: event(google_id: "abc").id } })

      expect(mcp_reply.dig("error", "data")).to start_with("delete_event needs the delete permission,")
      expect(google_calls).not_to have_been_made
    end
  end

  describe "with delete but not write" do
    def mcp_scopes = %w[read delete]

    it "refuses every event write, naming write" do
      refusals = %w[create_event delete_event edit_event move_event].map do |name|
        mcp_rpc("tools/call", { name:, arguments: {} })
        mcp_reply.dig("error", "data").start_with?("#{name} needs the write permission,")
      end

      expect(refusals).to all(be(true))
    end
  end

  it "tells the client what it may write to the calendar" do
    mcp_rpc("initialize",
            { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

    expect(mcp_result.fetch("instructions")).to include("work calendars take no change")
  end
end
