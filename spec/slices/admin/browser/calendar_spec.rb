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
end
