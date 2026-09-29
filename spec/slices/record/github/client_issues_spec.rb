# frozen_string_literal: true

RSpec.describe Record::GitHub::Client do
  let(:api) { "https://api.github.com" }
  let(:client) { Record::Slice["github.client"] }
  let(:known_url) { "https://github.com/aaronmallen/aaronmallen.me/issues/7" }
  let(:moved_url) { "https://github.com/aaronmallen/elsewhere/issues/3" }

  before { connect_github_token }

  def assigned = client.assigned_issues

  def check(urls = { "I_known" => known_url }) = client.issues(urls)

  def closed_as(reason) = stub_known(known(state: "CLOSED", stateReason: reason))

  def known(**) = github_issue("I_known", number: 7, **)

  def many_urls = (1..101).to_h { ["I_#{it}", "https://github.com/aaronmallen/aaronmallen.me/issues/#{it}"] }

  def stub_assigned(*responses) = stub_github(GitHubGraphQL::ASSIGNED_QUERY, *responses)

  def stub_batches
    stub_github(GitHubGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      github_issue_nodes(*ids.map { github_issue(it) })
    end
  end

  def stub_known(*nodes, **) = stub_github(GitHubGraphQL::ISSUES_QUERY, github_issue_nodes(*nodes, **))

  def stub_missing = stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)

  def stub_moved
    stub_rest_issue("aaronmallen/aaronmallen.me/issues/7",
                    { status: 301, headers: { "Location" => "#{api}/repos/aaronmallen/elsewhere/issues/3" } })
    stub_rest_issue("aaronmallen/elsewhere/issues/3", github_json(html_url: moved_url))
  end

  def stub_rest_issue(path, response) = stub_request(:get, "#{api}/repos/#{path}").to_return(response)

  def stub_vanished(response)
    stub_missing
    stub_rest_issue("aaronmallen/aaronmallen.me/issues/7", response)
  end

  describe "the open issues assigned to me" do
    let(:listed) do
      { body: "It broke", id: "I_one", reference: "someorg/tool#4", remote_state: "open", repo: "someorg/tool",
        title: "Fix it", url: "https://github.com/someorg/tool/issues/4" }
    end

    it "lists each one with its id, reference, title, body, URL and repository" do
      stub_assigned(github_issue_search(github_issue("I_one", repo: "someorg/tool", number: 4, title: "Fix it",
                                                              body: "It broke")))

      expect(assigned.items).to eq([listed])
    end

    it "pages through every result", :aggregate_failures do
      stub_assigned(github_issue_search(github_issue("I_one"), more: true), github_issue_search(github_issue("I_two")))

      expect(assigned.items.map { it[:id] }).to eq(%w[I_one I_two])
      expect(github_request(GitHubGraphQL::ASSIGNED_QUERY, cursor: "issues-page-2")).to have_been_made
    end

    it "searches every repository for open issues, not pull requests, assigned to the token's user" do
      stub_assigned(github_issue_search)
      assigned

      expect(github_request("is:issue is:open assignee:@me")).to have_been_made
    end

    it "skips a result that is not an issue" do
      stub_assigned(github_issue_search({}, github_issue("I_one")))

      expect(assigned.items.map { it[:id] }).to eq(%w[I_one])
    end

    it "records the rate limit it spent" do
      stub_assigned(github_issue_search(remaining: 4321))
      assigned

      expect(client.rate_limit_remaining).to eq(4321)
    end
  end

  describe "the issues already imported" do
    let(:still_mine) do
      { body: "Edited", id: "I_known", reference: "aaronmallen/aaronmallen.me#7", remote_state: "open",
        repo: "aaronmallen/aaronmallen.me", title: "Renamed", url: known_url }
    end

    it "reports an open issue still assigned to me, with its title and body" do
      stub_known(known(title: "Renamed", body: "Edited"))

      expect(check).to eq([still_mine])
    end

    it "reports an issue closed as completed" do
      closed_as("COMPLETED")

      expect(check.first).to include(remote_state: "completed")
    end

    it "reports an issue closed as not planned" do
      closed_as("NOT_PLANNED")

      expect(check.first).to include(remote_state: "not_planned")
    end

    it "reports an issue closed as a duplicate as not planned" do
      closed_as("DUPLICATE")

      expect(check.first).to include(remote_state: "not_planned")
    end

    it "reports an issue closed with no reason as completed" do
      closed_as(nil)

      expect(check.first).to include(remote_state: "completed")
    end

    it "reports an issue taken off me" do
      stub_known(known(assignees: ["MDQ6VXNlcjE="]))

      expect(check.first).to include(remote_state: "unassigned")
    end

    it "reports an issue moved to another repository, with where it went" do
      stub_missing
      stub_moved

      expect(check).to eq([{ id: "I_known", moved_to: moved_url, remote_state: "moved", url: known_url }])
    end

    it "reports a deleted issue" do
      stub_vanished({ status: 410 })

      expect(check).to eq([{ id: "I_known", remote_state: "deleted", url: known_url }])
    end

    it "reports an issue I can no longer see as deleted" do
      stub_vanished({ status: 404 })

      expect(check).to eq([{ id: "I_known", remote_state: "deleted", url: known_url }])
    end

    it "fails rather than call an issue deleted when GitHub refuses the check" do
      stub_vanished({ status: 500 })

      expect { check }.to raise_error(Record::GitHub::Client::Error)
    end

    it "fails rather than read every issue as taken off me when GitHub names no viewer" do
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_json(data: { nodes: [known], rateLimit: github_rate_limit }))

      expect { check }.to raise_error(Record::GitHub::Client::Error, /no viewer/)
    end

    it "asks for a hundred ids at a time", :aggregate_failures do
      stub_batches

      expect(check(many_urls).map { it[:id] }).to eq(many_urls.keys)
      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).to have_been_made.twice
    end

    it "records the rate limit it spent" do
      stub_known(known, remaining: 4200)
      check

      expect(client.rate_limit_remaining).to eq(4200)
    end
  end

  describe "with no GitHub token" do
    before { disconnect_github }

    it "reports itself unconfigured and asks GitHub nothing", :aggregate_failures do
      expect(client).not_to be_configured
      expect(assigned).to be_nil
      expect(check).to be_nil
      expect(a_request(:any, /api\.github\.com/)).not_to have_been_made
    end
  end
end
