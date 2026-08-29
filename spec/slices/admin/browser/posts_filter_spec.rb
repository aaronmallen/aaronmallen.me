# frozen_string_literal: true

RSpec.describe "Admin posts filter", type: :feature do
  before do
    create(:post, :draft, title: "A draft")
    create(:post, :published, title: "A published post")
    sign_in_to_admin
    visit "/admin/posts"
  end

  it "shows every post before a choice" do
    expect(page).to have_css(".li", count: 2)
  end

  describe "choosing drafts" do
    before { find(".seg-option", text: "drafts").click }

    it "submits the filter" do
      expect(page).to have_current_path("/admin/posts?status=draft")
    end

    it "lists only drafts", :aggregate_failures do
      expect(page).to have_css(".li", text: "A draft")
      expect(page).to have_no_css(".li", text: "A published post")
    end

    it "keeps drafts chosen" do
      expect(page).to have_checked_field("status", with: "draft", visible: :all)
    end
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
