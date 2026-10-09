# frozen_string_literal: true

RSpec.describe "Admin message snooze", type: :request do
  let(:now) { Time.utc(2026, 10, 7, 15, 10) }
  let(:later) { Time.utc(2026, 10, 9, 13) }
  let(:repo) { Contact::Slice["repos.message_queries"] }

  def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def acts = page.all(".msg-letter-acts button").map(&:text)

  def inbox
    get "/admin/inbox"
    page.all(".inbox-row-title").map(&:text)
  end

  def page = Capybara.string(last_response.body)

  before do
    allow(Time).to receive(:now).and_return(now)
    sign_in_to_admin
  end

  describe "the reading pane" do
    it "offers Wake in place of Snooze on a snoozed message" do
      message = create(:message, :read, snoozed_until: later)
      get "/admin/messages", status: "read", open: message.id

      expect(acts).to eq(["Mark unread", "Wake", "Label", "Spam", "Delete"])
    end

    it "offers Snooze again once the snooze has ended" do
      message = create(:message, snoozed_until: now - 60)
      get "/admin/messages", open: message.id

      expect(acts).to eq(["Mark read", "Snooze", "Label", "Spam", "Delete"])
    end

    it "offers neither on a spam message" do
      message = create(:message, :spam, snoozed_until: later)
      get "/admin/messages", status: "spam", open: message.id

      expect(acts).to eq(["Not spam", "Delete forever"])
    end

    it "posts the snooze to the message with the list that was open", :aggregate_failures do
      message = create(:message, :read)
      get "/admin/messages", status: "read", open: message.id

      form = page.find("dialog#snooze-message-#{message.id} form", visible: :all)
      expect(form[:action]).to eq("/admin/messages/#{message.id}/snooze")
      expect(form).to have_css("input[name='filter'][value='read']", visible: :all)
    end
  end

  describe "a snoozed row" do
    before do
      create(:message, subject: "Asleep", snoozed_until: later)
      create(:message, subject: "Awake")
      get "/admin/messages"
    end

    it "stays in the list, dimmed and marked snoozed", :aggregate_failures do
      expect(page).to have_css(".msg-item.snoozed .msg-item-title", text: "Asleep")
      expect(page).to have_css(".msg-item.snoozed .msg-item-snoozed", text: "snoozed")
    end

    it "leaves an awake row alone" do
      expect(page).to have_no_css(".msg-item.snoozed", text: "Awake")
    end
  end

  describe "snoozing" do
    let(:message) { create(:message, subject: "Later") }

    def snooze(**params) = act("/admin/messages/#{message.id}/snooze", **params)

    it "snoozes from a quick pick and returns to Messages", :aggregate_failures do
      snooze(pick: "2026-10-08T08:00", filter: "unread")

      expect(repo.by_id(message.id).snoozed_until).to eq(Time.utc(2026, 10, 8, 13))
      expect(last_response.location)
        .to end_with("/admin/messages?status=unread&open=#{message.id}#read-#{message.id}")
    end

    it "keeps the search and the tag on the way back" do
      snooze(pick: "2026-10-08T08:00", filter: "inbox", search: "later", tag: "billing")

      expect(last_response.location)
        .to end_with("/admin/messages?status=inbox&search=later&tag=billing&open=#{message.id}#read-#{message.id}")
    end

    it "snoozes until the time in the field" do
      snooze(snoozed_until: "2026-10-09T17:30")

      expect(repo.by_id(message.id).snoozed_until).to eq(Time.utc(2026, 10, 9, 22, 30))
    end

    it "drops the message from the inbox but keeps it in Messages", :aggregate_failures do
      snooze(pick: "2026-10-08T08:00")

      expect(inbox).not_to include("Later")
      get "/admin/messages"
      expect(page).to have_css(".msg-item.snoozed", text: "Later")
    end

    it "says until when" do
      snooze(pick: "2026-10-08T08:00")
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Snoozed until")
    end

    it "refuses a time in the past and returns to Messages", :aggregate_failures do
      snooze(snoozed_until: "2026-10-01T08:00")

      expect(repo.by_id(message.id).snoozed_until).to be_nil
      expect(last_response.location).to include("/admin/messages")
    end

    it "answers 404 for a message that isn't there" do
      act("/admin/messages/0/snooze", pick: "2026-10-08T08:00")

      expect(last_response.status).to eq(404)
    end

    it "refuses a post with a forged CSRF token" do
      post "/admin/messages/#{message.id}/snooze", _csrf_token: "forged", pick: "2026-10-08T08:00"

      expect(repo.by_id(message.id).snoozed_until).to be_nil
    end
  end

  describe "waking" do
    def wake(id, **params) = act("/admin/messages/#{id}/wake", **params)

    it "clears the snooze and returns to Messages", :aggregate_failures do
      message = create(:message, :read, snoozed_until: later)
      wake(message.id, filter: "read")

      expect(repo.by_id(message.id).snoozed_until).to be <= now
      expect(last_response.location).to end_with("/admin/messages?status=read&open=#{message.id}#read-#{message.id}")
    end

    it "keeps the search on the way back" do
      message = create(:message, snoozed_until: later)
      wake(message.id, filter: "inbox", search: "later")

      expect(last_response.location)
        .to end_with("/admin/messages?status=inbox&search=later&open=#{message.id}#read-#{message.id}")
    end

    it "puts the message back in the inbox" do
      message = create(:message, subject: "Back", snoozed_until: later)
      wake(message.id)

      expect(inbox).to include("Back")
    end

    it "answers 422 for a message that isn't snoozed" do
      message = create(:message)
      wake(message.id)

      expect(last_response.status).to eq(422)
    end

    it "answers 404 for a message that isn't there" do
      wake(0)

      expect(last_response.status).to eq(404)
    end
  end
end
