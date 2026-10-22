# frozen_string_literal: true

RSpec.describe "Admin contact sync", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def account(account_id) = connections.find { it.account_id == account_id }

  def connections = Services::Slice["repos.connection_queries"].for(:google)

  def contacts(account_id, **fields)
    post "/admin/services/#{account(account_id).id}/contacts", _csrf_token: admin_csrf_token, **fields
  end

  def options = connections.to_h { [it.account_id, [it.sync_contacts, it.saves_contacts]] }

  def queued = Contacts::Jobs::SyncContacts.jobs.size

  def sync_now = post("/admin/contacts/sync", _csrf_token: admin_csrf_token)

  before { sign_in_to_admin }

  describe "the options on each Google account" do
    before do
      connect_google(account_id: "me@example.com")
      connect_google(account_id: "work@example.com")
    end

    it "shows both switches off at first, with the second waiting on the first", :aggregate_failures do
      get "/admin/settings/services", selected: account("me@example.com").id.to_s
      form = "form[action='/admin/services/#{account('me@example.com').id}/contacts']"

      expect(page.find("#{form} input[role=switch][name=sync_contacts]")).not_to be_checked
      expect(page.find("#{form} input[role=switch][name=saves_contacts]")).to be_disabled
    end

    it "turns contact sync on for one account and leaves the others", :aggregate_failures do
      contacts("me@example.com", sync_contacts: "1")
      follow_redirect!

      expect(toast).to eq("me@example.com syncs its contacts")
      expect(options).to eq("me@example.com" => [true, false], "work@example.com" => [false, false])
    end

    it "saves new contacts to one account at a time", :aggregate_failures do
      contacts("me@example.com", sync_contacts: "1", saves_contacts: "1")
      contacts("work@example.com", sync_contacts: "1", saves_contacts: "1")
      follow_redirect!

      expect(toast).to eq("work@example.com syncs its contacts and takes new ones")
      expect(options).to eq("me@example.com" => [true, false], "work@example.com" => [true, true])
    end

    it "stops saving new contacts to an account that stops syncing", :aggregate_failures do
      contacts("me@example.com", sync_contacts: "1", saves_contacts: "1")
      contacts("me@example.com", sync_contacts: "0", saves_contacts: "1")
      follow_redirect!

      expect(toast).to eq("me@example.com no longer syncs contacts")
      expect(options.fetch("me@example.com")).to eq([false, false])
    end

    it "lists the contacts sync with the account's jobs" do
      get "/admin/settings/services", selected: account("me@example.com").id.to_s

      expect(page).to have_css(".svc-job", text: "Google Contacts sync")
    end
  end

  it "answers not found for an account that isn't Google" do
    connect_github_token
    connection = Services::Slice["repos.connection_queries"].for(:github).first
    post "/admin/services/#{connection.id}/contacts", _csrf_token: admin_csrf_token, sync_contacts: "1"

    expect(last_response.status).to eq(404)
  end

  describe "Sync now" do
    it "offers the button above the contacts" do
      get "/admin/contacts"

      expect(page).to have_css("form[action='/admin/contacts/sync'] button", text: "Sync now")
    end

    it "lands back on the contacts" do
      sync_now

      expect(last_response.location).to eq("/admin/contacts")
    end

    it "queues the same job the schedule runs", :aggregate_failures do
      sync_now
      follow_redirect!

      expect(queued).to eq(1)
      expect(toast).to eq(i18n.t("people_page.toasts.sync_queued"))
    end

    it "says so when the queue is down" do
      allow(Contacts::Jobs::SyncContacts).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      sync_now
      follow_redirect!

      expect(toast).to eq(i18n.t("queue_unavailable"))
    end
  end
end
