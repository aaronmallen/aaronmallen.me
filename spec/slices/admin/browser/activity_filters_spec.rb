# frozen_string_literal: true

RSpec.describe "Admin activity filters", type: :feature do
  let(:today) { Blog::TimeZone.today }

  def at(hour) = Blog::TimeZone.local_time(today.year, today.month, today.day, hour, 0)

  before do
    create(:post, :published, title: "A published post", published_at: at(9))
    create(:commit, commit_date: today, message: "add the view")
    sign_in_to_admin
    visit "/admin/activity"
  end

  it "shows every type before a choice" do
    expect(page).to have_css(".activity-event", count: 2)
  end

  it "offers no repository dropdown" do
    expect(page).to have_no_css("#activity-repo")
  end

  describe "unchecking a type" do
    before { uncheck "Blog posts" }

    it "puts the choice in the URL" do
      expect(page).to have_current_path(%r{/admin/activity\?.*types%5Bpost%5D=0})
    end

    it "drops that type from the timeline" do
      expect(page).to have_no_css(".activity-event", text: "A published post")
    end

    it "keeps the other types" do
      expect(page).to have_css(".activity-event", text: "add the view")
    end

    it "leaves the box unchecked" do
      expect(page).to have_unchecked_field("Blog posts")
    end

    it "still counts what the type would add" do
      expect(page.find(".activity-type:has(.fa-file-lines) .activity-type-count")).to have_text("1")
    end
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

  describe "choosing the 30d preset" do
    before { click_link "30d" }

    it "sets the dates" do
      expect(page).to have_field("From", with: (today - 29).iso8601)
    end

    it "marks itself active" do
      expect(page).to have_css(".seg-option.current", text: "30d")
    end

    it "keeps the dates in the URL" do
      expect(page).to have_current_path(/from=#{today - 29}&to=#{today}/)
    end
  end

  describe "searching the text" do
    before do
      fill_in "Contains", with: "add the"
      find_by_id("activity-q").native.send_keys(:enter)
    end

    it "keeps only what matches" do
      expect(page).to have_css(".activity-event", count: 1, text: "add the view")
    end

    it "puts the text in the URL" do
      expect(page).to have_current_path(/q=add\+the/)
    end
  end

  describe "searching a repo" do
    before do
      fill_in "Contains", with: "repo:nobody/nothing"
      find_by_id("activity-q").native.send_keys(:enter)
    end

    it "drops the commits of every other repo" do
      expect(page).to have_no_css(".activity-event", text: "add the view")
    end

    it "keeps the types that carry no repo" do
      expect(page).to have_css(".activity-event", text: "A published post")
    end
  end
end
