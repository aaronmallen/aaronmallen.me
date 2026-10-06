# frozen_string_literal: true

RSpec.describe "Admin activity filters", type: :feature do
  def at(hour) = Blog::TimeZone.local_time(today.year, today.month, today.day, hour, 0)

  before do
    create(:post, :published, title: "A published post", published_at: at(9))
    create(:commit, commit_date: today, message: "add the view")
    sign_in_to_admin
    visit "/admin/activity"
  end

  it "puts an unchecked type in the URL" do
    uncheck "Blog posts"

    expect(page).to have_current_path(%r{/admin/activity\?.*types%5Bpost%5D=0})
  end

  describe "going back after unchecking a type" do
    before do
      uncheck "Blog posts"
      page.assert_no_selector(".activity-event", text: "A published post")
      page.go_back
    end

    it "restores the earlier filters" do
      expect(page).to have_checked_field("Blog posts")
    end

    it "restores the earlier timeline" do
      expect(page).to have_css(".activity-event", count: 2)
    end
  end
end
