# frozen_string_literal: true

RSpec.describe "Admin today calendar", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:day) { Date.new(2026, 7, 14) }
  let(:now) { at(day, 10) }
  let(:mine) { create(:calendar, account: "me@example.com", name: "Aaron") }

  def card = page.all("section.card").find { it.has_css?("h2.card-title", exact_text: "Calendar") }

  def done_then(title, time) = [wording(:done), wording(:first_tomorrow), title, wording(:at, time:)].join(" ")

  def event(title, from = nil, to = nil, calendar: mine, on: day, **)
    times = from ? { starts_at: at(on, *from), ends_at: at(on, *to) } : {}

    create(:calendar_event, calendar_id: calendar.id, title:, starts_on: on, ends_on: on, **times, **)
  end

  def row(title) = card.find(".today-event", text: title, visible: :all)

  def shown = card.all(".card-body > .today-event .cal-event-name").map(&:text)

  def tally = card.find("[data-today-calendar-left]").text

  def wording(key, **) = Admin::Slice["i18n"].t(key, scope: "ui.components.calendar.today_card", **)

  before { sign_in_to_admin }

  it "links to the Calendar page" do
    get "/admin"

    expect(card.find("a.today-link", text: "week →")[:href]).to eq("/admin/calendar")
  end

  describe "a day with events" do
    before do
      event("Breakfast", [8], [8, 30])
      event("Lunch", [13], [14])
      event("Review", [10, 12], [10, 40])
      event("Standup", [9, 30], [10, 30])
      event("Holiday")
      get "/admin"
    end

    it "lists all-day events, then the ones left by start time" do
      expect(shown).to eq(%w[Holiday Standup Review Lunch])
    end

    it "folds the ended ones under N earlier", :aggregate_failures do
      earlier = card.find("details.today-more")

      expect(earlier.find("summary").text).to eq("1 earlier")
      expect(earlier.all(".cal-event-name", visible: :all).map { it.text(:all) }).to eq(["Breakfast"])
      expect(row("Breakfast")["data-state"]).to eq("past")
    end

    it "counts the timed events left" do
      expect(tally).to eq("3 of 4 left")
    end

    it "marks the running event now", :aggregate_failures do
      expect(row("Standup")["data-state"]).to eq("now")
      expect(row("Standup")).to have_css("[data-today-now] .pill.blue", text: "now")
      expect(row("Lunch")).to have_no_css("[data-today-now] .pill")
    end

    it "shows how soon the next event starts", :aggregate_failures do
      expect(row("Review")["data-state"]).to eq("next")
      expect(row("Review").find("[data-today-soon]").text).to eq("in 12m")
      expect(row("Lunch").find("[data-today-soon]").text).to eq("")
    end

    it "writes all day in place of a time" do
      expect(row("Holiday").find(".cal-event-time").text).to eq("all day")
    end
  end

  it "counts hours and minutes under three hours" do
    event("Planning", [12, 15], [13])
    get "/admin"

    expect(row("Planning").find("[data-today-soon]").text).to eq("in 2h 15m")
  end

  it "shows no countdown three hours out or more" do
    event("Planning", [13], [14])
    get "/admin"

    expect(row("Planning").find("[data-today-soon]").text).to eq("")
  end

  describe "with no events" do
    before { get "/admin" }

    it "says the calendar is empty" do
      expect(card).to have_css(".empty", exact_text: wording(:empty))
    end

    it "reads clear" do
      expect(tally).to eq("clear")
    end
  end

  it "reads clear with only all-day events" do
    event("Holiday")
    get "/admin"

    expect(tally).to eq("clear")
  end

  describe "once the day is done" do
    before { event("Breakfast", [8], [8, 30]) }

    it "names tomorrow's first timed event" do
      event("Holiday", on: day + 1)
      event("Late", [15], [16], on: day + 1)
      event("Dentist", [9], [9, 45], on: day + 1)
      get "/admin"

      expect(card.find(".today-para").text).to eq(done_then("Dentist", "09:00"))
    end

    it "says so alone with nothing tomorrow" do
      get "/admin"

      expect(card.find(".today-para").text).to eq(wording(:done))
    end
  end

  it "hides the events of calendars hidden on the Calendar page" do
    event("Secret", [11], [12], calendar: create(:calendar, name: "Hidden", hidden: true))
    event("Standup", [11], [12])
    get "/admin"

    expect(shown).to eq(["Standup"])
  end

  describe "a row" do
    before do
      event(
        "Coffee with Sean", [11], [12],
        place: "Sawada Coffee", meet_url: "https://meet.google.com/abc", notes: "Talk about Hanami",
        attendees: Sequel.pg_array(["Sean"], :text), link: "https://calendar.google.com/event?eid=1",
      )
      create(:calendar_event, calendar_id: mine.id, title: "Trip", starts_on: day - 1, ends_on: day + 2)
      get "/admin"
    end

    def body(title) = row(title).find(".cal-event-more", visible: :all)

    def buttons(title) = body(title).all("a.bt", visible: :all).to_h { [it.text(:all), it[:href]] }

    it "shows the calendar, times and place" do
      expect(row("Coffee with Sean").find(".cal-event-meta").text).to eq("Aaron11:00–12:00Sawada Coffee")
    end

    it "shows until when an event spans days" do
      expect(row("Trip").find(".cal-event-meta").text).to eq("Aaronuntil Jul 16")
    end

    it "offers a join button for a Meet link" do
      expect(row("Coffee with Sean").find("a.today-event-join")[:href]).to eq("https://meet.google.com/abc")
    end

    it "opens to notes, guests and the account" do
      expect(body("Coffee with Sean").all("p", visible: :all).map { it.text(:all) })
        .to eq(["Talk about Hanami", "Sean", "me@example.com"])
    end

    it "opens to Join Meet, Prep task and Google Calendar" do
      expect(buttons("Coffee with Sean")).to eq(
        "Join Meet" => "https://meet.google.com/abc",
        "Prep task" => "/admin/tasks/new?origin=today&title=Coffee%20with%20Sean",
        "Google Calendar" => "https://calendar.google.com/event?eid=1",
      )
    end

    it "opens the new-task dialog with the title from Prep task", :aggregate_failures do
      prep = body("Coffee with Sean").find("a", text: "Prep task", visible: :all)

      expect(prep["data-dialog-open"]).to eq("task-create")
      expect(prep["data-prep-title"]).to eq("Coffee with Sean")
    end
  end

  it "fills the title on the new task page" do
    get "/admin/tasks/new", title: "Coffee with Sean"

    expect(page.find_field("task[title]").value).to eq("Coffee with Sean")
  end
end
