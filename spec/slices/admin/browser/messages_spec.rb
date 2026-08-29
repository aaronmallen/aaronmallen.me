# frozen_string_literal: true

RSpec.describe "Admin messages", type: :feature do
  before do
    create(:message, subject: "Waiting")
    create(:message, :read, subject: "Answered")
    sign_in_to_admin
    visit "/admin/messages"
  end

  describe "the filter" do
    it "shows the unread messages first", :aggregate_failures do
      expect(page).to have_css(".li-title", text: "Waiting")
      expect(page).to have_no_css(".li-title", text: "Answered")
    end

    describe "choosing read" do
      before { find(".seg-option", exact_text: "read").click }

      it "submits the filter" do
        expect(page).to have_current_path("/admin/messages?status=read")
      end

      it "lists only read messages", :aggregate_failures do
        expect(page).to have_css(".li-title", text: "Answered")
        expect(page).to have_no_css(".li-title", text: "Waiting")
      end

      it "keeps read chosen" do
        expect(page).to have_checked_field("status", with: "read", visible: :all)
      end
    end
  end

  describe "marking the unread message read" do
    before { find(".li", text: "Waiting").click_button("Read") }

    it "takes it off the unread list" do
      expect(page).to have_no_css(".li-title", text: "Waiting")
    end

    it "says so" do
      expect(page).to have_css("[data-toast]", text: "Marked read")
    end

    it "finds it under read" do
      find(".seg-option", exact_text: "read").click

      expect(page).to have_css(".li-title", text: "Waiting")
    end
  end
end
