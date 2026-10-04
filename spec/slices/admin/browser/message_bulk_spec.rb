# frozen_string_literal: true

RSpec.describe "Admin bulk message actions", type: :feature do
  let(:repo) { Contact::Slice["repos.message_repo"] }

  def acts = find("[data-bulk-acts]", visible: :all)

  def all_box = find("[data-bulk-all] input")

  def box(subject) = find(".li", text: subject).find("input[name='ids[]']")

  def confirm_dialog = find("dialog#confirm-dialog[open]")

  def subjects(status) = repo.by_status(status).map(&:subject)

  before do
    %w[first second third].each_with_index do |subject, index|
      create(:message, subject:, received_at: Time.utc(2026, 9, 3 - index))
    end
    create(:message, :read, subject: "answered")
    sign_in_to_admin
  end

  describe "with scripts on" do
    before { visit "/admin/messages" }

    it "hides the actions while nothing is ticked" do
      expect(acts).not_to be_visible
    end

    it "shows the actions once a row is ticked" do
      box("second").check

      expect(acts).to be_visible
    end

    it "marks the ticked messages read and leaves the rest", :aggregate_failures do
      box("first").check
      box("third").check
      within("form#message-bulk") { click_button("Read") }

      expect(page).to have_css("[data-toast] .toast", text: "Marked 2 messages read")
      expect(subjects("unread")).to eq(["second"])
    end

    it "marks every message on the page read with select all", :aggregate_failures do
      all_box.check
      within("form#message-bulk") { click_button("Read") }

      expect(page).to have_css("[data-toast] .toast", text: "Marked 3 messages read")
      expect(subjects("unread")).to be_empty
    end

    it "asks before it deletes", :aggregate_failures do
      box("second").check
      within("form#message-bulk") { click_button("Delete") }
      confirm_dialog.click_button("Yes")

      expect(page).to have_css("[data-toast] .toast", text: "Deleted 1 message")
      expect(subjects("unread")).to eq(%w[first third])
    end

    it "keeps the messages when the delete is declined" do
      box("second").check
      within("form#message-bulk") { click_button("Delete") }
      confirm_dialog.click_button("No")

      expect(subjects("unread").size).to eq(3)
    end
  end

  describe "on the read list" do
    before { visit "/admin/messages?status=read" }

    it "moves the ticked messages back to unread", :aggregate_failures do
      box("answered").check
      within("form#message-bulk") { click_button("Unread") }

      expect(page).to have_css("[data-toast] .toast", text: "Moved 1 message back to unread")
      expect(subjects("read")).to be_empty
    end
  end
end
