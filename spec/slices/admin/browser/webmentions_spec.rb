# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :feature do
  let(:target) { create(:post, :published, slug: "hello", title: "Hello") }

  before do
    create(:webmention, :reply, post: target, author_name: "Ada")
    create(:webmention, :approved, post: target, author_name: "Grace")
    sign_in_to_admin
    visit "/admin/webmentions"
  end

  describe "the filter" do
    it "shows the pending mentions first", :aggregate_failures do
      expect(page).to have_css(".wm-author", text: "Ada")
      expect(page).to have_no_css(".wm-author", text: "Grace")
    end

    describe "choosing approved" do
      before { find(".seg-option", text: "approved").click }

      it "submits the filter" do
        expect(page).to have_current_path("/admin/webmentions?status=approved")
      end

      it "lists only approved mentions", :aggregate_failures do
        expect(page).to have_css(".wm-author", text: "Grace")
        expect(page).to have_no_css(".wm-author", text: "Ada")
      end

      it "keeps approved chosen" do
        expect(page).to have_checked_field("status", with: "approved", visible: :all)
      end
    end
  end

  describe "approving a mention" do
    before { click_button "Approve" }

    it "shows the toast" do
      expect(page).to have_css(".toast", text: "Approved · now visible on the post")
    end

    it "takes the mention out of pending" do
      expect(page).to have_no_css(".wm-author", text: "Ada")
    end
  end

  describe "ignoring a mention" do
    before { click_button "Ignore" }

    it "shows the toast" do
      expect(page).to have_css(".toast", text: "Ignored · hidden from the post")
    end

    it "takes the mention out of pending" do
      expect(page).to have_no_css(".wm-author", text: "Ada")
    end

    it "lists the mention under ignored" do
      find(".seg-option", text: "ignored").click

      expect(page).to have_css(".wm-author", text: "Ada")
    end
  end

  describe "marking a mention as spam with a note" do
    before do
      fill_in "Why spam? (optional)", with: "link farm"
      click_button "Spam"
    end

    it "shows the toast" do
      expect(page).to have_css(".toast", text: "Marked as spam")
    end

    it "shows the note under spam" do
      find(".seg-option", text: "spam").click

      expect(page).to have_css(".wm-reason", text: "Spam: link farm")
    end
  end

  describe "turning a setting off" do
    before { uncheck "Receive webmentions" }

    it "saves without a button" do
      expect(page).to have_css(".toast", text: "Settings saved")
    end

    it "keeps the setting off" do
      page.assert_selector(".toast", text: "Settings saved")

      expect(page).to have_unchecked_field("Receive webmentions")
    end
  end
end
