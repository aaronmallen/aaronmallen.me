# frozen_string_literal: true

RSpec.describe "API issue sync", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def queued = [Tasks::Jobs::SyncIssues.jobs.size, Tasks::Jobs::SyncLinearIssues.jobs.size]

  def status = last_response.status

  def sync
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/tasks/issues/sync", nil, headers
    JSON.parse(last_response.body)
  end

  def unconfigured = "no GitHub token or Linear key is set, so no issue sync can run"

  describe "POST /api/v1/tasks/issues/sync" do
    describe "with a GitHub token" do
      before { connect_github_token }

      it "queues the GitHub sync alone and says so", :aggregate_failures do
        expect([sync, status]).to eq([{ "queued" => ["github"] }, 200])
        expect(queued).to eq([1, 0])
      end

      it "asks GitHub for nothing inside the request" do
        sync

        expect(a_request(:any, /api\.github\.com/)).not_to have_been_made
      end
    end

    describe "with a Linear key and no GitHub token" do
      before do
        disconnect_github
        connect_linear(LinearGraphQL::KEY)
      end

      it "queues the Linear sync alone and says so", :aggregate_failures do
        expect(sync).to eq("queued" => ["linear"])
        expect(queued).to eq([0, 1])
      end
    end

    describe "with a GitHub token and a Linear key" do
      before do
        connect_github_token
        connect_linear(LinearGraphQL::KEY)
      end

      it "queues both syncs and says so", :aggregate_failures do
        expect(sync).to eq("queued" => %w[github linear])
        expect(queued).to eq([1, 1])
      end
    end

    describe "with neither" do
      before { disconnect_github }

      it "refuses with the admin's reason and queues nothing", :aggregate_failures do
        expect([sync, status]).to eq([{ "error" => "failed", "message" => unconfigured }, 500])
        expect(queued).to eq([0, 0])
      end
    end
  end

  describe "the MCP tool" do
    it "queues as the endpoint does and says which", :aggregate_failures do
      connect_github_token
      connect_linear(LinearGraphQL::KEY)

      expect(mcp_answer("sync_issues")).to eq("queued" => %w[github linear])
      expect(queued).to eq([1, 1])
    end

    it "refuses with the message the endpoint gives", :aggregate_failures do
      disconnect_github

      expect(mcp_text("sync_issues")).to eq(sync.fetch("message"))
      expect(queued).to eq([0, 0])
    end
  end
end
