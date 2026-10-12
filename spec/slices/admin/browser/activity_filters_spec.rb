# frozen_string_literal: true

RSpec.describe "Admin activity filters", type: :feature do
  def at(hour) = Blog::TimeZone.local_time(today.year, today.month, today.day, hour, 0)

  before do
    create(:post, :published, title: "A published post", published_at: at(9))
    create(:commit, commit_date: today, message: "add the view")
    sign_in_to_admin
    visit "/admin"
    visit "/admin/activity"
    page.execute_script("window.stayed = true")
  end

  def toggle(name) = find(".activity-type", text: name).click

  describe "unchecking a type" do
    before do
      toggle "Blog posts"
      page.assert_no_selector(".activity-event", text: "A published post")
    end

    it "puts the unchecked type in the URL" do
      expect(page).to have_current_path(%r{/admin/activity\?.*types%5Bpost%5D=0})
    end

    it "redraws the timeline without loading the page" do
      expect(page.evaluate_script("window.stayed")).to be(true)
    end

    it "shows the same timeline on reload", :aggregate_failures do
      page.refresh

      expect(page).to have_unchecked_field("Blog posts", visible: :all)
      expect(page).to have_css(".activity-event", count: 1)
    end

    it "saves the filtered query in a view" do
      find(".saved-views summary", text: "Save view").click
      panel = find(".saved-views details[open] > .saved-view-panel")
      panel.fill_in("Name", with: "No posts")
      panel.click_on("Save view")

      expect(page).to have_css(".saved-view-link[href*='types%5Bpost%5D=0']", text: "No posts")
    end
  end

  it "filters by the text typed in place", :aggregate_failures do
    find_field("Contains").send_keys("view", :enter)

    expect(page).to have_current_path(/q=view/)
    expect(page.evaluate_script("window.stayed")).to be(true)
  end

  describe "going back after three filters" do
    before do
      [["Blog posts", "post%5D=0"], ["Commits", "commit%5D=0"], ["Blog posts", "post%5D=1"]].each do |name, query|
        toggle name
        page.assert_current_path(/#{Regexp.escape(query)}/)
      end
      page.go_back
    end

    it "leaves the page" do
      expect(page).to have_current_path("/admin")
    end
  end
end
