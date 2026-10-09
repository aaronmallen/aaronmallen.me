# frozen_string_literal: true

RSpec.describe "Admin commits import", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def api = "https://api.github.com"

  def commit_queries = Record::Slice["repos.commit_queries"]

  def enqueued = Record::Jobs::ImportCommits.jobs

  def import = post("/admin/commits/import", _csrf_token: admin_csrf_token)

  def with_token
    connect_github_token
  end

  describe "signed in with a token" do
    before do
      sign_in_to_admin
      with_token
    end

    it "redirects back to Today" do
      import

      expect(last_response.location).to eq("/admin")
    end

    it "queues the import job" do
      import

      expect(enqueued.size).to eq(1)
    end

    it "says the import is queued" do
      import
      follow_redirect!

      expect(toast).to eq(i18n.t("today_page.toasts.queued"))
    end

    it "asks GitHub for nothing inside the request" do
      import

      expect(a_request(:get, "#{api}/user/repos").with(query: hash_including(sort: "pushed"))).not_to have_been_made
    end

    it "imports nothing inside the request", :aggregate_failures do
      import

      expect([commit_queries.today, commit_queries.last_synced_at]).to eq([[], nil])
    end

    it "rejects an import without a CSRF token", :aggregate_failures do
      post "/admin/commits/import"

      expect([last_response.status, enqueued]).to eq([403, []])
    end
  end

  describe "signed in without a token" do
    before do
      disconnect_github
      sign_in_to_admin
    end

    it "says the token isn't set" do
      import
      follow_redirect!

      expect(toast).to eq(i18n.t("today_page.toasts.not_configured"))
    end

    it "queues nothing" do
      import

      expect(enqueued).to be_empty
    end
  end

  describe "the backfill page, now gone" do
    before do
      sign_in_to_admin
      with_token
    end

    it "answers 404 for the page" do
      get "/admin/commits/backfill"

      expect(last_response.status).to eq(404)
    end

    %w[/admin/commits/backfill /admin/commits/backfill/clear /admin/commits/backfill/stop].each do |path|
      it "answers 404 for a post to #{path}" do
        post path, _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "signed out" do
    it "queues nothing" do
      post "/admin/commits/import"

      expect(enqueued).to be_empty
    end
  end
end
