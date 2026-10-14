# frozen_string_literal: true

RSpec.describe "API commits, pull requests and syncs", type: :request do
  include Spec::DB::FactoryHelper.new(:record)

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, params = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1#{path}", params, headers)
    JSON.parse(last_response.body)
  end

  def march = { from: "2026-03-01", to: "2026-03-31" }

  def status = last_response.status

  describe "GET /api/v1/commits" do
    it "lists the window's commits, newest first, with a 200" do
      older = create(:commit, commit_date: Date.new(2026, 3, 1))
      newer = create(:commit, commit_date: Date.new(2026, 3, 31))
      create(:commit, commit_date: Date.new(2026, 4, 1))

      expect([call_api(:get, "/commits", march).fetch("commits").map { it.fetch("sha") }, status])
        .to eq([[newer.sha, older.sha], 200])
    end

    it "narrows to the repositories named" do
      blog = create(:commit, repo: "aaronmallen/blog", commit_date: Date.new(2026, 3, 2))
      create(:commit, repo: "aaronmallen/other", commit_date: Date.new(2026, 3, 4))

      expect(call_api(:get, "/commits", march.merge(repos: "blog")).fetch("commits").map { it.fetch("sha") })
        .to eq([blog.sha])
    end

    it "answers the same JSON as list_commits" do
      create(:commit, commit_date: Date.new(2026, 3, 2))

      expect(call_api(:get, "/commits", march)).to eq(mcp_answer("list_commits", **march))
    end

    it "refuses a window with no to with a 422" do
      call_api(:get, "/commits", { from: "2026-03-01" })

      expect(status).to eq(422)
    end
  end

  describe "POST /api/v1/commits/import" do
    it "queues the import", :aggregate_failures do
      connect_github_token

      expect([call_api(:post, "/commits/import", "{}"), status]).to eq([{ "status" => "queued" }, 200])
      expect(Record::Jobs::ImportCommits.jobs.size).to eq(1)
    end

    it "answers with a 503 when GitHub isn't connected" do
      disconnect_github

      expect([call_api(:post, "/commits/import", "{}").fetch("message"), status])
        .to eq(["GitHub isn't connected, so no import can run", 503])
    end
  end

  describe "GET /api/v1/pull_requests" do
    it "lists the window's pull requests with their text unmarked" do
      create(:pull_request, title: "fix the feed", ready_at: Time.utc(2026, 3, 2, 12))

      expect(call_api(:get, "/pull_requests", march).fetch("pull_requests").map { it.fetch("title") })
        .to eq(["fix the feed"])
    end

    it "answers what list_pull_requests answers, less the untrusted marks" do
      create(:pull_request, ready_at: Time.utc(2026, 3, 2, 12))

      expect(call_api(:get, "/pull_requests", march)).to eq(trusted(mcp_answer("list_pull_requests", **march)))
    end
  end

  describe "GET /api/v1/sync_state" do
    it "answers nothing synced and nothing failing on a fresh site" do
      expect([call_api(:get, "/sync_state"),
              status]).to eq([{ "commits_last_synced_at" => nil, "failures" => [] }, 200])
    end

    it "answers each failing sync" do
      Record::Slice["repos.sync_state_mutations"].record_failure(
        Blog::Types::SyncName["commits"], :github_failed, at: Time.utc(2026, 3, 1, 8), message: "502",
      )

      expect(call_api(:get, "/sync_state")).to eq(mcp_answer("read_sync_state"))
    end
  end

  describe "GET /api/v1/tokens" do
    it "lists the live tokens and never the token itself" do
      api_token

      expect([call_api(:get, "/tokens").fetch("tokens").map(&:keys), status])
        .to eq([[%w[id name created_at last_used_at]], 200])
    end

    it "answers the same JSON as list_api_tokens" do
      expect(call_api(:get, "/tokens")).to eq(mcp_answer("list_api_tokens"))
    end
  end
end
