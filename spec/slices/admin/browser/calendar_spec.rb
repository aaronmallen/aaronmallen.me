# frozen_string_literal: true

RSpec.describe "Admin calendar", type: :feature do
  let(:day) { Date.new(2026, 7, 14) }

  before do
    create(:post, :scheduled, title: "A post on its day",
                              published_at: Blog::TimeZone.local_time(day.year, day.month, day.day, 9))
    sign_in_to_admin
    visit "/admin/calendar?month=2026-07"
    execute_script("window.calendarLoaded = true")
    find(".cal-day:has(time[datetime='2026-07-14']) a.cal-link").click
  end

  def panel = find("[data-calendar-panel]")

  it "opens the day's panel without loading the page", :aggregate_failures do
    expect(panel).to have_link("A post on its day")
    expect(evaluate_script("window.calendarLoaded")).to be(true)
  end

  it "shows the day in the address" do
    expect(page).to have_current_path("/admin/calendar?day=2026-07-14")
  end

  it "marks the day as picked" do
    expect(page).to have_css(".cal-picked time[datetime='2026-07-14']")
  end

  it "moves focus to the panel" do
    expect(page).to have_css("[data-calendar-panel='2026-07-14']:focus")
  end

  describe "when an earlier day answers after a later one" do
    def open_day(date) = find(".cal-day:has(time[datetime='#{date}']) a.cal-link").click

    before do
      panel.assert_matches_selector("[data-calendar-panel='2026-07-14']")
      hold = request_gate.hold("/admin/calendar")
      open_day("2026-07-15")
      hold.wait_for_arrival
      open_day("2026-07-16")
      panel.assert_matches_selector("[data-calendar-panel='2026-07-16']")
      hold.release
      page.driver.wait_for_network_idle
    end

    it "keeps the later day's panel", :aggregate_failures do
      expect(panel).to match_selector("[data-calendar-panel='2026-07-16']")
      expect(page).to have_current_path("/admin/calendar?day=2026-07-16")
    end
  end
end
