# frozen_string_literal: true

RSpec.describe "Admin issue sync", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def enqueued = Tasks::Jobs::SyncIssues.jobs

  def sync = post("/admin/tasks/issues/sync", _csrf_token: admin_csrf_token)

  describe "signed in with a token" do
    before do
      sign_in_to_admin
      connect_github_token
    end

    it "offers the button on the External tab" do
      get "/admin/tasks", filter: "external"

      expect(page).to have_css("form[action='/admin/tasks/issues/sync'] button", text: "Sync issues")
    end

    it "leaves the button off the other tabs" do
      get "/admin/tasks", filter: "next"

      expect(page).to have_no_css("form[action='/admin/tasks/issues/sync']")
    end

    it "redirects back to the External tab" do
      sync

      expect(last_response.location).to eq("/admin/tasks?filter=external")
    end

    it "queues the sync job" do
      sync

      expect(enqueued.size).to eq(1)
    end

    it "queues no Linear job without a Linear key" do
      connect_linear
      sync

      expect(Tasks::Jobs::SyncLinearIssues.jobs).to be_empty
    end

    it "says the sync is queued" do
      sync
      follow_redirect!

      expect(toast).to eq(i18n.t("tasks_page.toasts.issue_sync.queued"))
    end

    it "asks GitHub for nothing inside the request" do
      sync

      expect(a_request(:any, /api\.github\.com/)).not_to have_been_made
    end

    it "rejects a sync without a CSRF token", :aggregate_failures do
      post "/admin/tasks/issues/sync"

      expect([last_response.status, enqueued]).to eq([403, []])
    end
  end

  describe "signed in without a token" do
    before do
      disconnect_github
      sign_in_to_admin
    end

    it "says the token isn't set" do
      sync
      follow_redirect!

      expect(toast).to eq(i18n.t("tasks_page.toasts.issue_sync.not_configured"))
    end

    it "queues nothing" do
      sync

      expect(enqueued).to be_empty
    end
  end

  describe "signed in with a Linear key and no GitHub token" do
    before do
      disconnect_github
      connect_linear(LinearGraphQL::KEY)
      sign_in_to_admin
    end

    it "queues the Linear sync alone", :aggregate_failures do
      sync

      expect([Tasks::Jobs::SyncLinearIssues.jobs.size, enqueued.size]).to eq([1, 0])
    end

    it "says the sync is queued" do
      sync
      follow_redirect!

      expect(toast).to eq(i18n.t("tasks_page.toasts.issue_sync.queued"))
    end
  end

  describe "signed in with a token and a Linear key" do
    before do
      sign_in_to_admin
      connect_github_token
      connect_linear(LinearGraphQL::KEY)
    end

    it "queues both syncs" do
      sync

      expect([Tasks::Jobs::SyncLinearIssues.jobs.size, enqueued.size]).to eq([1, 1])
    end
  end

  describe "signed out" do
    it "queues nothing" do
      post "/admin/tasks/issues/sync"

      expect(enqueued).to be_empty
    end
  end
end
