# frozen_string_literal: true

RSpec.describe "Admin calendar events", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:day) { Date.new(2026, 7, 14) }
  let(:mine) { create(:calendar, account: "me@example.com", name: "Aaron") }
  let(:work) { create(:calendar, account: "work@example.com", name: "Work", writable: false) }

  def at(date, hour, minute = 0) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour, minute)

  def cell(date) = page.find(".cal-day:has(time[datetime='#{date.iso8601}'])")

  def event(calendar, title, hour = nil, **)
    times = hour ? { starts_at: at(day, hour), ends_at: at(day, hour, 30) } : {}

    create(:calendar_event, calendar_id: calendar.id, title:, starts_on: day, ends_on: day, **times, **)
  end

  def panel = page.find("[data-calendar-panel]")

  def picked
    page.all(".cal-picker input[type=checkbox]", visible: :all)
        .to_h { [it.find(:xpath, "..", visible: :all).text(:all), it.checked?] }
  end

  def show(**params) = post("/admin/calendar/calendars", { _csrf_token: admin_csrf_token, day: day.iso8601, **params })

  def stored = Calendar::Slice["repos.calendar_queries"].listed.to_h { [it.name, it.hidden] }

  def toast = page.find("[data-toast]", visible: :all).text(:all)

  def visit_day = get("/admin/calendar", day: day.iso8601)

  it "changes no calendar for anybody who has not signed in" do
    post "/admin/calendar/calendars", day: day.iso8601, shown: []

    expect(Calendar::Slice["repos.calendar_queries"].listed.map(&:hidden)).to all(be(false))
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a day with three events" do
      before do
        event(mine, "Standup", 9)
        event(work, "On-call")
        event(work, "Sync", 14)
        visit_day
      end

      it "shows the first two with their start times, then counts the rest" do
        expect(cell(day).all(".cal-mark.event, .cal-mark.more").map(&:text))
          .to eq(["On-call", "09:00Standup", "+1 events"])
      end

      it "tints each event in its calendar's tone" do
        expect(cell(day).all(".cal-mark.event").map { it[:style] }).to eq(
          ["--tone: var(--color-mk-green-text)", "--tone: var(--color-mk-pink-text)"],
        )
      end
    end

    it "shows an event on every day it covers" do
      create(:calendar_event, calendar_id: work.id, title: "On-call", starts_on: day, ends_on: day + 2)
      visit_day

      expect((day..(day + 3)).map { cell(it).has_css?(".cal-mark.event", text: "On-call") })
        .to eq([true, true, true, false])
    end

    describe "the day panel" do
      before do
        event(
          mine, "Coffee with Sean", 8,
          place: "Sawada Coffee", meet_url: "https://meet.google.com/abc", notes: "Talk about Hanami",
          attendees: Sequel.pg_array(["Sean"], :text), link: "https://calendar.google.com/event?eid=1",
        )
        create(:calendar_event, calendar_id: work.id, title: "On-call", starts_on: day, ends_on: day + 6)
        visit_day
      end

      def row(title) = panel.find(".cal-event", text: title)

      it "lists the day's events, all-day ones first" do
        expect(panel.all(".cal-event .cal-event-time").map(&:text)).to eq(["all day", "08:00"])
      end

      it "names each event's calendar, times, place and last day", :aggregate_failures do
        expect(row("Coffee").find(".cal-event-meta").text).to eq("Aaron08:00–08:30Sawada Coffee")
        expect(row("On-call").find(".cal-event-meta").text).to eq("Workuntil Jul 20")
      end

      it "opens to its notes, guests, account and links", :aggregate_failures do
        more = row("Coffee").find(".cal-event-more", visible: :all)

        expect(more.text(:all)).to include("Talk about Hanami", "Sean", "me@example.com")
        expect(more).to have_link("Join Meet", href: "https://meet.google.com/abc", visible: :all)
        expect(more).to have_link("Google Calendar", href: "https://calendar.google.com/event?eid=1", visible: :all)
      end

      it "offers to join a Meet without opening the event" do
        expect(row("Coffee")).to have_link("Join Coffee with Sean", href: "https://meet.google.com/abc")
      end
    end

    describe "the picker" do
      before do
        event(mine, "Standup", 9)
        event(work, "Sync", 14)
      end

      it "lists each calendar under its account and marks the ones that take no writes", :aggregate_failures do
        visit_day

        expect(page.all(".cal-picker-account legend", visible: :all).map { |legend| legend.text(:all) })
          .to eq(%w[me@example.com work@example.com])
        expect(picked).to eq("Aaron" => true, "Workread-only" => true)
      end

      it "counts the calendars it shows" do
        work.then { Calendar::Slice["repos.calendar_mutations"].show([mine.id]) }
        visit_day

        expect(page).to have_css(".saved-view-menu summary", text: "Calendars 1/2")
      end

      describe "saving a pick" do
        before do
          show(shown: [mine.id.to_s])
          follow_redirect!
        end

        it "says so and goes back to the day", :aggregate_failures do
          expect(toast).to eq("Calendars saved")
          expect(last_request.params).to include("day" => day.iso8601)
        end

        it "hides the events of every calendar left out" do
          expect(cell(day).all(".cal-mark.event").map(&:text)).to eq(["09:00Standup"])
        end

        it "holds the pick on the next visit", :aggregate_failures do
          visit_day

          expect(picked).to eq("Aaron" => true, "Workread-only" => false)
          expect(panel).to have_no_css(".cal-event", text: "Sync")
        end
      end

      it "shows only the work accounts' calendars from Work only" do
        connect_google(account_id: "work@example.com", work: true)
        create(:calendar, account: "me@example.com", name: "Holidays", writable: false)
        show(preset: "work")

        expect(stored).to eq("Aaron" => true, "Holidays" => true, "Work" => false)
      end

      it "shows every calendar again from Show all" do
        Calendar::Slice["repos.calendar_mutations"].show([])
        show(preset: "all")

        expect(stored).to eq("Aaron" => false, "Work" => false)
      end

      it "hides every calendar when nothing is ticked" do
        show

        expect(stored).to eq("Aaron" => true, "Work" => true)
      end
    end

    it "shows no picker before any calendar syncs" do
      visit_day

      expect(page).to have_no_css(".cal-picker", visible: :all)
    end
  end
end
