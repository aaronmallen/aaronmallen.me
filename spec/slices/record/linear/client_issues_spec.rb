# frozen_string_literal: true

RSpec.describe Record::Linear::Client do
  let(:client) { Record::Slice["linear.client"] }
  let(:other_key) { "lin_api_two" }

  before { connect_linear(LinearGraphQL::KEY) }

  def assigned = client.assigned_issues

  def check(urls = { "issue-known" => known_url }) = client.issues(urls)

  def known(**) = linear_issue("issue-known", key: "ABC-7", **)

  def known_url = "https://linear.app/aaronmallen/issue/abc-7/sync-my-issues"

  def many_urls = (1..101).to_h { ["issue-#{it}", "https://linear.app/aaronmallen/issue/abc-#{it}"] }

  def stub_assigned(*, **) = stub_linear(LinearGraphQL::ASSIGNED_QUERY, *, **)

  def stub_known(*nodes, **) = stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues(*nodes), **)

  describe "the open issues assigned to me" do
    let(:listed) do
      { body: "It broke", id: "issue-one", key: "ABC-4", remote_state: "open", title: "Fix it",
        url: "https://linear.app/aaronmallen/issue/abc-4/sync-my-issues" }
    end

    it "lists each one with its id, key, title, description and URL" do
      stub_assigned(linear_assigned(linear_issue("issue-one", key: "ABC-4", title: "Fix it",
                                                              description: "It broke")))

      expect(assigned.items).to eq([listed])
    end

    it "pages through every result", :aggregate_failures do
      stub_assigned(linear_assigned(linear_issue("issue-one"), more: true), linear_assigned(linear_issue("issue-two")))

      expect(assigned.items.map { it[:id] }).to eq(%w[issue-one issue-two])
      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY, cursor: "issues-page-2")).to have_been_made
    end

    it "stops after ten pages and says it was cut short", :aggregate_failures do
      stub_assigned(linear_assigned(linear_issue("issue-one"), more: true))

      expect(assigned).to be_cut_short
      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY)).to have_been_made.times(10)
    end

    it "asks only for issues that are not completed or canceled" do
      stub_assigned(linear_assigned)
      assigned

      expect(linear_request('{state: {type: {nin: ["completed", "canceled"]}}}')).to have_been_made
    end

    it "sends the key as it is, with no scheme" do
      stub_assigned(linear_assigned)
      assigned

      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY, key: LinearGraphQL::KEY)).to have_been_made
    end

    it "reports a started issue as started" do
      stub_assigned(linear_assigned(linear_issue("issue-one", state: "started")))

      expect(assigned.items.first).to include(remote_state: "started")
    end

    context "with a key for each of two workspaces" do
      before do
        connect_linear(LinearGraphQL::KEY, other_key)
        stub_assigned(linear_assigned(linear_issue("issue-one", key: "ABC-1")), key: LinearGraphQL::KEY)
        stub_assigned(linear_assigned(linear_issue("issue-two", key: "XYZ-9", assignee: "other-viewer"),
                                      viewer: "other-viewer"), key: other_key)
      end

      let(:both) do
        { "issue-one" => "ABC-1", "issue-two" => "XYZ-9" }.map { |id, key| { id:, key:, remote_state: "open" } }
      end

      it "lists the issues from both", :aggregate_failures do
        expect(assigned.items.map { it.slice(:id, :key, :remote_state) }).to eq(both)
        expect(assigned).not_to be_cut_short
      end
    end
  end

  describe "the issues already imported" do
    it "reports an issue still assigned to me, with its title and description" do
      stub_known(known(title: "Renamed", description: "Edited"))

      renamed = { body: "Edited", id: "issue-known", key: "ABC-7", remote_state: "open", title: "Renamed",
                  url: known_url }

      expect(check).to eq([renamed])
    end

    {
      "triage" => "open", "backlog" => "open", "unstarted" => "open", "started" => "started",
      "completed" => "completed", "canceled" => "not_planned",
    }.each do |type, state|
      it "reports an issue in a #{type} state as #{state}" do
        stub_known(known(state: type))

        expect(check.first).to include(remote_state: state)
      end
    end

    it "reports an issue taken off me" do
      stub_known(known(assignee: "someone-else"))

      expect(check.first).to include(remote_state: "unassigned")
    end

    it "reports an issue with nobody on it as taken off me" do
      stub_known(known(assignee: nil))

      expect(check.first).to include(remote_state: "unassigned")
    end

    it "reports an issue in the trash as deleted" do
      stub_known(known(trashed: true))

      expect(check.first).to include(remote_state: "deleted")
    end

    it "reports an issue Linear no longer returns as deleted" do
      stub_known

      expect(check).to eq([{ id: "issue-known", remote_state: "deleted", url: known_url }])
    end

    it "reports an archived issue by its state alone", :aggregate_failures do
      stub_known(known(archivedAt: "2026-09-28T12:00:00Z", state: "completed"))

      expect(check.first).to include(remote_state: "completed")
      expect(linear_request("includeArchived: true")).to have_been_made
    end

    it "reports an issue moved to another team under the same id, with its new key and URL" do
      moved = "https://linear.app/aaronmallen/issue/ops-2/sync-my-issues"
      stub_known(known(key: "OPS-2", url: moved))

      expect(check.first).to include(id: "issue-known", key: "OPS-2", remote_state: "open", url: moved)
    end

    it "fails rather than read every issue as taken off me when Linear names no viewer" do
      stub_linear(LinearGraphQL::ISSUES_QUERY, linear_json(data: { issues: { nodes: [known] } }))

      expect { check }.to raise_error(Record::Linear::Client::Error, /no viewer/)
    end

    it "asks for a hundred ids at a time", :aggregate_failures do
      stub_linear(LinearGraphQL::ISSUES_QUERY) do |request|
        linear_issues(*JSON.parse(request.body).dig("variables", "ids").map { linear_issue(it) })
      end

      expect(check(many_urls).map { it[:id] }).to eq(many_urls.keys)
      expect(linear_request(LinearGraphQL::ISSUES_QUERY)).to have_been_made.twice
    end

    it "asks nothing when there is nothing to check", :aggregate_failures do
      expect(check({})).to eq([])
      expect(a_request(:any, /api\.linear\.app/)).not_to have_been_made
    end

    context "with a key for each of two workspaces" do
      let(:urls) { { "issue-known" => known_url, "issue-there" => "https://linear.app/other/issue/xyz-9" } }

      before do
        connect_linear(LinearGraphQL::KEY, other_key)
        stub_known(known, key: LinearGraphQL::KEY)
        there = linear_issue("issue-there", key: "XYZ-9", state: "completed", assignee: "other-viewer")
        stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues(there, viewer: "other-viewer"), key: other_key)
      end

      it "finds each issue in its own workspace" do
        expect(check(urls).map { it.slice(:id, :remote_state) }).to eq(
          [{ id: "issue-known", remote_state: "open" }, { id: "issue-there", remote_state: "completed" }],
        )
      end

      it "asks the second workspace only for what the first did not find" do
        check(urls)

        expect(linear_request(LinearGraphQL::ISSUES_QUERY, key: other_key, ids: ["issue-there"])).to have_been_made
      end
    end
  end

  describe "a failed request" do
    it "raises rate limited when Linear says so in the body" do
      stub_assigned(linear_errors("RATELIMITED", "Rate limit exceeded"))

      expect { assigned }.to raise_error(Record::Linear::Client::RateLimited)
    end

    it "raises rate limited on a 429" do
      stub_assigned({ status: 429 })

      expect { assigned }.to raise_error(Record::RateLimited)
    end

    it "raises an error Linear names" do
      stub_assigned(linear_errors("AUTHENTICATION_ERROR", "Authentication required"))

      expect { assigned }.to raise_error(Record::Linear::Client::Error, /Authentication required/)
    end

    it "raises an error on a failed response" do
      stub_assigned({ status: 502 })

      expect { assigned }.to raise_error(Record::Error, /502/)
    end

    it "raises an error when the connection fails" do
      stub_request(:post, LinearGraphQL::URL).to_timeout

      expect { assigned }.to raise_error(Record::Linear::Client::Error, /failed/)
    end
  end

  describe "with no Linear keys" do
    before { connect_linear }

    it "reports itself unconfigured and asks Linear nothing", :aggregate_failures do
      expect(client).not_to be_configured
      expect(assigned).to be_nil
      expect(check).to be_nil
      expect(a_request(:any, /api\.linear\.app/)).not_to have_been_made
    end
  end
end
