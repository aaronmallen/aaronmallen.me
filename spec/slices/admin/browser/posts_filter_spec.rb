# frozen_string_literal: true

RSpec.describe "Admin posts filter", type: :feature do
  before do
    create(:post, :draft, title: "A draft")
    sign_in_to_admin
    visit "/admin/posts"
  end

  it "submits the filter once drafts is chosen" do
    find(".seg-option", text: "drafts").click

    expect(page).to have_current_path("/admin/posts?status=draft")
  end

  describe "going back after a choice" do
    before do
      find(".seg-option", text: "drafts").click
      page.assert_current_path("/admin/posts?status=draft")
      page.go_back
    end

    it "shows the choice that matches the page" do
      expect(page).to have_checked_field("status", with: "all", visible: :all)
    end

    it "submits the same choice again" do
      find(".seg-option", text: "drafts").click

      expect(page).to have_current_path("/admin/posts?status=draft")
    end
  end
end
