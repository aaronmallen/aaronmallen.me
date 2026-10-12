# frozen_string_literal: true

RSpec.describe "Admin calendar event menu", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:day) { Date.new(2026, 7, 14) }
  let(:mine) { create(:calendar, account: "me@example.com", google_id: "me@example.com", name: "Aaron") }

  def deletes = page.all("form[data-morph][action$='/delete']", visible: :all)

  def event(calendar, title, **)
    create(:calendar_event, calendar_id: calendar.id, title:, starts_on: day, ends_on: day, **)
  end

  def field(form, name) = form.find("input[name=#{name}]", visible: :all).value

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  it "sends me to sign in when I am signed out" do
    get "/admin/calendar/events/1/menu"

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for an event that is gone" do
      get "/admin/calendar/events/0/menu"

      expect(last_response.status).to eq(404)
    end

    describe "an event on a writable calendar" do
      let(:lunch) do
        event(mine, "Lunch", link: "https://calendar.google.com/event?eid=abc", meet_url: "https://meet.google.com/abc")
      end

      before { get "/admin/calendar/events/#{lunch.id}/menu", day: day.iso8601 }

      it "heads the menu with the event's title" do
        expect(page).to have_css("[data-context-menu] > .ctx-head", text: "Lunch")
      end

      it "holds every action the event takes" do
        expect(items).to eq(["Edit", "Join Meet", "Open in Google Calendar", "Delete event"])
      end

      it "opens Google Calendar and Meet in a new tab", :aggregate_failures do
        expect(page).to have_css("a.ctx-item[href='https://calendar.google.com/event?eid=abc'][target=_blank]")
        expect(page).to have_css("a.ctx-item[href='https://meet.google.com/abc'][target=_blank]")
      end

      it "edits in a dialog that morphs back to the day", :aggregate_failures do
        form = page.find("dialog form[data-morph][action='/admin/calendar/events/#{lunch.id}']", visible: :all)

        expect(field(form, "day")).to eq(day.iso8601)
        expect(form.find("input[name=title]", visible: :all).value).to eq("Lunch")
      end

      it "deletes on a second click back to the day", :aggregate_failures do
        expect(deletes.size).to eq(1)

        delete = deletes.first
        expect(delete).to have_css("[data-confirm-inline]", visible: :all)
        expect(field(delete, "day")).to eq(day.iso8601)
      end
    end

    it "offers to delete one event of a series or the whole series", :aggregate_failures do
      standup = event(mine, "Standup", google_id: "standup_20260714", recurring_id: "standup")
      get "/admin/calendar/events/#{standup.id}/menu", day: day.iso8601

      expect(items).to eq(["Edit", "Delete this one", "Delete the whole series"])
      expect(deletes.map { field(it, "scope") }).to eq(%w[this all])
    end

    it "offers only the links for an event on a read-only calendar" do
      work = create(:calendar, account: "work@example.com", name: "Work", writable: false)
      sync = event(work, "Sync", link: "https://calendar.google.com/event?eid=sync")
      get "/admin/calendar/events/#{sync.id}/menu"

      expect(items).to eq(["Open in Google Calendar"])
    end

    it "points each event row on the calendar at its menu" do
      lunch = event(mine, "Lunch")
      get "/admin/calendar", day: day.iso8601

      expect(page).to have_css(".cal-event[data-menu='/admin/calendar/events/#{lunch.id}/menu?day=#{day.iso8601}']")
    end
  end
end
