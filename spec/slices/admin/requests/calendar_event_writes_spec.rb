# frozen_string_literal: true

RSpec.describe "Admin calendar event writes", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:day) { Date.new(2026, 7, 14) }
  let(:mine) { create(:calendar, account: "me@example.com", google_id: "me@example.com", name: "Aaron") }
  let(:work) do
    create(:calendar, account: "work@example.com", google_id: "work@example.com", name: "Work", writable: false)
  end

  def event(calendar, title, **)
    times = { starts_at: at(day, 9), ends_at: at(day, 9, 30) }

    create(:calendar_event, calendar_id: calendar.id, title:, starts_on: day, ends_on: day, **times, **)
  end

  def events_url = "#{Calendar::Operations::SyncCalendar::API}/calendars/me%40example.com/events"

  def fields(**) = { title: "Lunch", date: day.iso8601, starts: "12:00", ends: "13:00", all_day: "0", place: "", ** }

  def google_json(body = {}) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def queued = Calendar::Jobs::SyncCalendar.jobs.size

  def row(title) = page.find("[data-calendar-panel] .cal-event", text: title)

  def said(key) = Admin::Slice["i18n"].t(key, scope: "ui.components.calendar.field_error")

  def send_form(path, **) = post(path, { _csrf_token: admin_csrf_token, day: day.iso8601, ** })

  def spanning(title, ends_on, starts, ends, **)
    times = { starts_at: at(day, *starts), ends_at: at(ends_on, *ends) }

    event(mine, title, ends_on:, **times, **)
  end

  def timed(date, starts, ends, last: date)
    {
      start: { date: nil, dateTime: at(date, *starts).iso8601, timeZone: Blog::TimeZone::NAME },
      end: { date: nil, dateTime: at(last, *ends).iso8601, timeZone: Blog::TimeZone::NAME },
    }
  end

  def whole(first, after)
    { start: { date: first.iso8601, dateTime: nil, timeZone: nil },
      end: { date: after.iso8601, dateTime: nil, timeZone: nil } }
  end

  before do
    connect_google(account_id: "me@example.com", scopes: Calendar::Operations::SyncCalendar::SCOPES, token: "ya29.me")
    stub_request(:any, %r{googleapis\.com/calendar}).to_return(google_json)
  end

  it "writes nothing to Google for anybody who has not signed in" do
    post "/admin/calendar/events", calendar: mine.id, **fields

    expect(a_request(:post, events_url)).not_to have_been_made
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "creating an event" do
      it "adds it to Google and syncs the mirror", :aggregate_failures do
        send_form("/admin/calendar/events", calendar: mine.id, **fields(place: "Sawada"))

        expect(a_request(:post, events_url).with(body: { summary: "Lunch", location: "Sawada", **timed(day, 12, 13) }))
          .to have_been_made
        expect(queued).to eq(1)
        expect(toast).to eq("Added to Aaron")
      end

      it "sends an all-day event as whole days" do
        send_form("/admin/calendar/events", calendar: mine.id, **fields(all_day: "1", starts: "", ends: ""))

        expect(a_request(:post, events_url).with(body: hash_including(whole(day, day + 1)))).to have_been_made
      end

      describe "refused" do
        let(:form) { page.find("form#cal-event-new-form", visible: :all) }

        def error(field) = form.find("#cal-event-new-#{field}-error", visible: :all).text(:all)

        def value(field) = form.find("#cal-event-new-#{field}", visible: :all).value

        describe "with an end before the start" do
          before { send_form("/admin/calendar/events", calendar: mine.id, **fields(ends: "11:00", place: "Sawada")) }

          it "answers 422 and sends nothing to Google", :aggregate_failures do
            expect(last_response.status).to eq(422)
            expect(a_request(:post, events_url)).not_to have_been_made
          end

          it "opens the form again with what I typed", :aggregate_failures do
            expect(page).to have_css("details.cal-new-event[open]", visible: :all)
            expect([value(:title), value(:ends), value(:place), value(:calendar)])
              .to eq(["Lunch", "11:00", "Sawada", mine.id.to_s])
          end

          it "says why on the end" do
            expect(error(:ends)).to eq(said("ends.ends_first"))
          end
        end

        it "names a bad clock on its own field", :aggregate_failures do
          send_form("/admin/calendar/events", calendar: mine.id, **fields(starts: "25:00", ends: "noon"))

          expect([error(:starts), error(:ends)]).to eq([said("starts.format"), said("ends.format")])
          expect(form).to have_css("#cal-event-new-starts[aria-invalid='true']", visible: :all)
        end

        it "names a title it can't take" do
          send_form("/admin/calendar/events", calendar: mine.id, **fields(title: "  "))

          expect(error(:title)).to eq(said("title.blank"))
        end

        it "keeps an all-day event all day" do
          send_form("/admin/calendar/events", calendar: mine.id, **fields(title: "", all_day: "1"))

          expect(form).to have_checked_field("all_day", visible: :all)
        end
      end

      it "refuses a work calendar", :aggregate_failures do
        send_form("/admin/calendar/events", calendar: work.id, **fields)

        expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
        expect(toast).to eq("That calendar is read-only")
      end

      describe "with a calendar I can only view" do
        before do
          mine
          shared = create(:calendar, account: mine.account, google_id: "holidays", writable: false)
          [work, shared].each { send_form("/admin/calendar/events", calendar: it.id, **fields) }
        end

        it "adds nothing to it or to a work calendar" do
          expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
        end

        it "says work calendars and ones I can only view take no new events" do
          get "/admin/calendar", day: day.iso8601

          expect(page.find(".cal-event-form .hint", visible: :all).text(:all))
            .to eq(Admin::Slice["i18n"].t("ui.components.calendar.event_form.read_only"))
        end
      end

      it "says so when Google refuses it" do
        stub_request(:post, events_url).to_return(status: 403, **google_json)
        send_form("/admin/calendar/events", calendar: mine.id, **fields)

        expect(toast).to eq("Google didn't take that · try again")
      end
    end

    describe "editing an event made in Google" do
      it "changes it in Google", :aggregate_failures do
        standup = event(mine, "Standup", google_id: "abc")
        send_form("/admin/calendar/events/#{standup.id}", **fields(title: "Standup", date: (day + 1).iso8601))

        expect(a_request(:patch, "#{events_url}/abc").with(body: hash_including(timed(day + 1, 12, 13))))
          .to have_been_made
        expect(toast).to eq("Saved to Aaron")
      end

      it "keeps the days an all-day event covers" do
        trip = create(:calendar_event, calendar_id: mine.id, google_id: "trip", starts_on: day, ends_on: day + 2)
        send_form("/admin/calendar/events/#{trip.id}", **fields(all_day: "1", date: (day + 7).iso8601))

        expect(a_request(:patch, "#{events_url}/trip").with(body: hash_including(whole(day + 7, day + 10))))
          .to have_been_made
      end

      it "keeps an overnight event ending the next day" do
        shift = spanning("Night shift", day + 1, 22, 2, google_id: "shift")
        send_form("/admin/calendar/events/#{shift.id}", **fields(title: "Late shift", starts: "22:00", ends: "02:00"))

        expect(a_request(:patch, "#{events_url}/shift").with(body: hash_including(timed(day, 22, 2, last: day + 1))))
          .to have_been_made
      end

      it "keeps the days a timed event covers" do
        offsite = spanning("Offsite", day + 2, 9, 17, google_id: "offsite")
        send_form("/admin/calendar/events/#{offsite.id}", **fields(title: "Retreat", starts: "09:00", ends: "17:00"))

        expect(a_request(:patch, "#{events_url}/offsite").with(body: hash_including(timed(day, 9, 17, last: day + 2))))
          .to have_been_made
      end

      it "ends an overnight event moved to daytime on its start day" do
        shift = spanning("Night shift", day + 1, 22, 1, google_id: "shift")
        send_form("/admin/calendar/events/#{shift.id}", **fields(starts: "09:00", ends: "10:00"))

        expect(a_request(:patch, "#{events_url}/shift").with(body: hash_including(timed(day, 9, 10))))
          .to have_been_made
      end

      it "keeps a multi-day event's days when its clocks stop crossing midnight" do
        trip = spanning("Trip", day + 2, 22, 1, google_id: "trip")
        send_form("/admin/calendar/events/#{trip.id}", **fields(starts: "09:00", ends: "10:00"))

        expect(a_request(:patch, "#{events_url}/trip").with(body: hash_including(timed(day, 9, 10, last: day + 1))))
          .to have_been_made
      end

      it "keeps a 22:00 to 00:00 event ending at midnight the next day" do
        late = spanning("Late", day + 1, 22, 0, google_id: "late")
        send_form("/admin/calendar/events/#{late.id}", **fields(starts: "22:00", ends: "00:00"))

        expect(a_request(:patch, "#{events_url}/late").with(body: hash_including(timed(day, 22, 0, last: day + 1))))
          .to have_been_made
      end

      describe "switching an all-day event to timed" do
        let(:trip) do
          create(:calendar_event, calendar_id: mine.id, google_id: "trip", starts_on: day, ends_on: day + 1)
        end

        it "ends it on its start day" do
          send_form("/admin/calendar/events/#{trip.id}", **fields(starts: "09:00", ends: "17:00"))

          expect(a_request(:patch, "#{events_url}/trip").with(body: hash_including(timed(day, 9, 17))))
            .to have_been_made
        end

        it "ends it the next day when its clocks cross midnight" do
          send_form("/admin/calendar/events/#{trip.id}", **fields(starts: "22:00", ends: "01:00"))

          expect(a_request(:patch, "#{events_url}/trip").with(body: hash_including(timed(day, 22, 1, last: day + 1))))
            .to have_been_made
        end
      end

      describe "refused" do
        let(:standup) { event(mine, "Standup", google_id: "abc", recurring_id: "standup") }

        def error(id, field) = form(id).find("##{id}-#{field}-error", visible: :all).text(:all)

        def form(id) = page.find("form##{id}-form", visible: :all)

        describe "from the day panel" do
          def id = "cal-event-#{standup.id}"

          before { send_form("/admin/calendar/events/#{standup.id}", scope: "all", **fields(ends: "11:00")) }

          it "answers 422 and sends nothing to Google", :aggregate_failures do
            expect(last_response.status).to eq(422)
            expect(a_request(:patch, /googleapis/)).not_to have_been_made
          end

          it "opens the form again with what I typed", :aggregate_failures do
            expect(row("Standup")).to have_css("details.cal-event-edit[open]", visible: :all)
            expect(form(id).find("##{id}-title", visible: :all).value).to eq("Lunch")
            expect(form(id)).to have_checked_field("scope", with: "all", visible: :all)
          end

          it "says why on the end" do
            expect(error(id, :ends)).to eq(said("ends.ends_first"))
          end
        end

        it "answers the menu's dialog with a form of the same id" do
          send_form("/admin/calendar/events/#{standup.id}", menu: "1", **fields(starts: "9"))

          expect(error("cal-event-#{standup.id}-menu", :starts)).to eq(said("starts.format"))
        end
      end

      it "refuses an event on a work calendar" do
        sync = event(work, "Sync")
        send_form("/admin/calendar/events/#{sync.id}", **fields)

        expect(toast).to eq("That calendar is read-only")
      end
    end

    describe "editing a recurring instance" do
      let(:standup) { event(mine, "Standup", google_id: "standup_20260714", recurring_id: "standup") }

      before do
        stub_request(:get, "#{events_url}/standup")
          .to_return(google_json(start: { dateTime: at(day - 30, 9).iso8601, timeZone: Blog::TimeZone::NAME }))
      end

      it "changes only this event", :aggregate_failures do
        send_form("/admin/calendar/events/#{standup.id}", scope: "this", **fields)

        expect(a_request(:patch, "#{events_url}/standup_20260714")).to have_been_made
        expect(a_request(:patch, "#{events_url}/standup")).not_to have_been_made
      end

      it "moves every event in the series by as much as this one moved" do
        send_form("/admin/calendar/events/#{standup.id}", scope: "all", **fields(date: (day + 1).iso8601))

        expect(a_request(:patch, "#{events_url}/standup").with(body: hash_including(timed(day - 29, 12, 13))))
          .to have_been_made
      end

      it "keeps the days a timed series event covers" do
        offsite = spanning("Offsite", day + 2, 9, 17, google_id: "offsite_20260714", recurring_id: "standup")
        send_form("/admin/calendar/events/#{offsite.id}", scope: "all", **fields(starts: "09:00", ends: "17:00"))

        expect(a_request(:patch, "#{events_url}/standup")
          .with(body: hash_including(timed(day - 30, 9, 17, last: day - 28)))).to have_been_made
      end
    end

    describe "deleting an event" do
      it "deletes it from Google", :aggregate_failures do
        standup = event(mine, "Standup", google_id: "abc")
        send_form("/admin/calendar/events/#{standup.id}/delete")

        expect(a_request(:delete, "#{events_url}/abc")).to have_been_made
        expect(toast).to eq("Deleted from Aaron")
      end

      it "deletes the whole series when asked" do
        standup = event(mine, "Standup", google_id: "standup_20260714", recurring_id: "standup")
        send_form("/admin/calendar/events/#{standup.id}/delete", scope: "all")

        expect(a_request(:delete, "#{events_url}/standup")).to have_been_made
      end

      it "refuses an event on a work calendar" do
        sync = event(work, "Sync")
        send_form("/admin/calendar/events/#{sync.id}/delete")

        expect(a_request(:delete, /googleapis/)).not_to have_been_made
      end

      it "answers 404 for an event it doesn't know" do
        send_form("/admin/calendar/events/0/delete")

        expect(last_response.status).to eq(404)
      end
    end

    describe "moving an event" do
      def ahead = Blog::TimeZone.today + 3

      def move(record, to = target) = send_form("/admin/calendar/events/#{record.id}/move", to: to.iso8601)

      def move_form(title) = row(title).first("form.cal-move", minimum: 0)

      def placed(date, **)
        times = { starts_at: at(date, 9), ends_at: at(date, 9, 30) }

        event(mine, "Standup", google_id: "abc", starts_on: date, ends_on: date, **times, **)
      end

      def stored(record) = Calendar::Slice["repos.calendar_queries"].event(record.id)

      def target = ahead + 2

      it "moves it in Google to the same time on the new day", :aggregate_failures do
        standup = placed(ahead)
        move(standup)

        expect(a_request(:patch, "#{events_url}/abc").with(body: timed(target, 9, [9, 30]))).to have_been_made
        expect([stored(standup).starts_at, queued]).to eq([at(target, 9), 1])
        expect(toast).to eq("Moved to #{target.strftime('%b %-d, %Y')}")
      end

      it "keeps the days an all-day event covers" do
        trip = create(:calendar_event, calendar_id: mine.id, google_id: "trip", starts_on: ahead, ends_on: ahead + 2)
        move(trip, ahead + 7)

        expect(a_request(:patch, "#{events_url}/trip").with(body: whole(ahead + 7, ahead + 10))).to have_been_made
      end

      it "moves only this instance of a recurring event", :aggregate_failures do
        move(placed(ahead, google_id: "standup_1", recurring_id: "standup"))

        expect(a_request(:patch, "#{events_url}/standup_1")).to have_been_made
        expect(a_request(:any, "#{events_url}/standup")).not_to have_been_made
      end

      it "refuses an event on a work calendar", :aggregate_failures do
        move(event(work, "Sync", starts_on: ahead, ends_on: ahead))

        expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
        expect(toast).to eq("That calendar is read-only")
      end

      it "refuses a day before today", :aggregate_failures do
        move(placed(ahead), Blog::TimeZone.today - 1)

        expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
        expect(toast).to eq("A move lands on today or a day after it")
      end

      it "leaves the event where it was when Google refuses it", :aggregate_failures do
        stub_request(:patch, "#{events_url}/abc").to_return(status: 403, **google_json)
        standup = placed(ahead)
        move(standup)

        expect(stored(standup).starts_on).to eq(ahead)
        expect(toast).to eq("Google didn't take that · try again")
      end

      it "answers 404 for an event it doesn't know" do
        send_form("/admin/calendar/events/0/move", to: target.iso8601)

        expect(last_response.status).to eq(404)
      end

      it "offers a move form only on a writable calendar", :aggregate_failures do
        standup = placed(ahead)
        event(work, "Sync", starts_on: ahead, ends_on: ahead)
        get "/admin/calendar", day: ahead.iso8601

        expect(move_form("Standup")&.[](:action)).to eq("/admin/calendar/events/#{standup.id}/move")
        expect(move_form("Sync")).to be_nil
      end
    end

    describe "the day panel" do
      let(:standup) { event(mine, "Standup", recurring_id: "standup") }

      before do
        standup
        event(work, "Sync")
        get "/admin/calendar", day: day.iso8601
      end

      it "offers a new event on the writable calendars only, under each account" do
        options = page.all(".cal-new-event optgroup", visible: :all).to_h do |group|
          [group[:label], group.all("option", visible: :all).map { it.text(:all) }]
        end

        expect(options).to eq("me@example.com" => ["Aaron"])
      end

      it "offers to edit and delete an event on a writable calendar", :aggregate_failures do
        expect(row("Standup")).to have_css("form[action='/admin/calendar/events/#{standup.id}']", visible: :all)
        expect(row("Standup")).to have_button("Delete", visible: :all)
      end

      it "asks this or all for a recurring instance" do
        expect(row("Standup").all(".seg-option", visible: :all).map { it.text(:all) })
          .to eq(["This event", "All events", "This event", "All events"])
      end

      it "offers no changes on a work calendar and says so", :aggregate_failures do
        expect(row("Sync")).to have_no_css("form", visible: :all)
        expect(row("Sync").text(:all)).to include("Read-only here")
      end
    end

    describe "once I mark the account a work account" do
      let(:lunch) { event(mine, "Lunch") }

      before do
        connection = Services::Slice["repos.connection_queries"].for(:google).first
        post "/admin/services/#{connection.id}/work", _csrf_token: admin_csrf_token, work: "1"
      end

      it "says the site never changes a work account's calendars", :aggregate_failures do
        send_form("/admin/calendar/events", calendar: mine.id, **fields)
        expect(toast).to eq("That calendar is read-only")

        get "/admin/settings/services", selected: Services::Slice["repos.connection_queries"].for(:google).first.id.to_s
        expect(Capybara.string(last_response.body).find("#services .settings-side"))
          .to have_css(".hint", text: Admin::Slice["i18n"].t("ui.components.services.detail.work_hint"))
      end

      it "refuses a new event on a calendar Google lets me write", :aggregate_failures do
        send_form("/admin/calendar/events", calendar: mine.id, **fields)

        expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
        expect(toast).to eq("That calendar is read-only")
      end

      it "refuses to change or delete an event there", :aggregate_failures do
        send_form("/admin/calendar/events/#{lunch.id}", **fields)
        expect(toast).to eq("That calendar is read-only")

        send_form("/admin/calendar/events/#{lunch.id}/delete")
        expect(a_request(:any, %r{googleapis\.com/calendar})).not_to have_been_made
      end
    end

    describe "while Redis is down" do
      let(:standup) { event(mine, "Standup", google_id: "abc") }

      def agent = Hanami.app["honeybadger.agent"]

      before do
        allow(agent).to receive(:notify)
        allow(Calendar::Jobs::SyncCalendar).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      end

      it "still adds the event and tells Honeybadger the sync waits", :aggregate_failures do
        send_form("/admin/calendar/events", calendar: mine.id, **fields)

        expect(toast).to eq("Added to Aaron")
        expect(agent).to have_received(:notify).with(RedisClient::CannotConnectError)
      end

      it "still saves an edit" do
        send_form("/admin/calendar/events/#{standup.id}", **fields(title: "Standup"))

        expect(toast).to eq("Saved to Aaron")
      end

      it "still moves an event" do
        send_form("/admin/calendar/events/#{standup.id}/move", to: (Blog::TimeZone.today + 3).iso8601)

        expect(toast).to start_with("Moved to")
      end

      it "still deletes an event" do
        send_form("/admin/calendar/events/#{standup.id}/delete")

        expect(toast).to eq("Deleted from Aaron")
      end
    end

    it "offers no new event when no calendar takes writes" do
      event(work, "Sync")
      get "/admin/calendar", day: day.iso8601

      expect(page).to have_no_css(".cal-new-event", visible: :all)
    end
  end
end
