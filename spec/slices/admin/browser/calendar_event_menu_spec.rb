# frozen_string_literal: true

RSpec.describe "Admin calendar event menu", type: :feature do
  let(:day) { Blog::TimeZone.today }
  let(:calendar) { create(:calendar, account: "me@example.com", google_id: "me@example.com", name: "Aaron") }
  let(:url) { "#{Calendar::Operations::SyncCalendar::API}/calendars/me%40example.com/events/abc" }

  def edit_title(to)
    item("Edit").click
    within("dialog[open]") do
      fill_in "Title", with: to
      click_on "Save"
    end
  end

  before do
    sign_in_to_admin
    connect_google(account_id: "me@example.com", scopes: Calendar::Operations::SyncCalendar::SCOPES, token: "ya29.me")
    stub_request(:any, url).to_return(body: "{}", headers: { "Content-Type" => "application/json" })
    create(:calendar_event, calendar_id: calendar.id, google_id: "abc", title: "Coffee", starts_on: day, ends_on: day,
                            starts_at: at(day, 9), ends_at: at(day, 10))
    visit "/admin/calendar?day=#{day.iso8601}"
    execute_script("window.kept = true")
    find("[data-calendar-panel] .cal-event-time", text: "09:00").right_click
  end

  it "edits the event in a dialog and stays on the page", :aggregate_failures do
    edit_title("Tea")

    expect(page).to have_css(".toast", text: "Saved to Aaron")
    expect(a_request(:patch, url).with(body: hash_including(summary: "Tea"))).to have_been_made
    expect(kept_page?).to be(true)
  end

  describe "deleting" do
    before { item("Delete event").click }

    it "asks for a second click", :aggregate_failures do
      expect(item(admin_t("ui.views.calendar.event_menu.confirm_delete"))).to be_truthy
      expect(a_request(:delete, url)).not_to have_been_made
    end

    it "deletes on the second click and stays on the page", :aggregate_failures do
      item(admin_t("ui.views.calendar.event_menu.confirm_delete")).click

      expect(page).to have_css(".toast", text: "Deleted from Aaron")
      expect(a_request(:delete, url)).to have_been_made
      expect(kept_page?).to be(true)
    end
  end
end
