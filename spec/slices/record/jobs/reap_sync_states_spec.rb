# frozen_string_literal: true

RSpec.describe Record::Jobs::ReapSyncStates do
  def commit_mutations = Record::Slice["repos.commit_mutations"]
  def commit_queries = Record::Slice["repos.commit_queries"]
  let(:gone) { "aaronmallen/renamed" }
  let(:repo) { "aaronmallen/aaronmallen.me" }

  def commits_sync = Blog::Types::SyncName["commits"]

  def leave_traces(name)
    commit_mutations.record_backfilled_to(name, at: Time.now - 3600)
    sync_state_mutations.record_failure(commits_sync, :github_failed, repo: name)
  end

  before do
    connect_github_token
    stub_repos(github_repository(repo))
  end

  def reap = described_class.new.perform

  def stub_repos(*repositories, **) = stub_github(GitHubGraphQL::REPOS_QUERY, github_repos_page(*repositories, **))

  def stub_repos_answer(*responses) = stub_github(GitHubGraphQL::REPOS_QUERY, *responses)

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  def traces(name) = [commit_queries.backfilled_to(name), sync_state_queries.failure(commits_sync, repo: name)]

  describe "a repository GitHub no longer lists" do
    before { leave_traces(gone) }

    it "drops its back edge and failure, so Today stops reporting it and no walk starts again" do
      reap

      expect(traces(gone)).to eq([nil, nil])
    end
  end

  describe "a repository that is merely quiet" do
    before { leave_traces(repo) }

    it "keeps everything it left", :aggregate_failures do
      reap

      expect(commit_queries.backfilled_to(repo)).not_to be_nil
      expect(sync_state_queries.failure(commits_sync, repo:)).to include(reason: "github_failed")
    end
  end

  it "keeps the whole sync's failure, which names no repository" do
    sync_state_mutations.record_failure(commits_sync, :not_configured)
    reap

    expect(sync_state_queries.failure(commits_sync)).to include(reason: "not_configured")
  end

  it "reads every page of the repository list" do
    stub_repos_answer(github_repos_page(github_repository(repo), more: true),
                      github_repos_page(github_repository(gone)))
    leave_traces(gone)
    reap

    expect(commit_queries.backfilled_to(gone)).not_to be_nil
  end

  it "keeps a repository nobody has pushed to in years" do
    stub_repos(github_repository(repo), github_repository(gone, pushed_at: nil))
    leave_traces(gone)
    reap

    expect(commit_queries.backfilled_to(gone)).not_to be_nil
  end

  describe "when the list cannot be trusted" do
    before { leave_traces(gone) }

    def kept? = !commit_queries.backfilled_to(gone).nil?

    it "reaps nothing with no token, asking GitHub for nothing", :aggregate_failures do
      disconnect_github
      reap

      expect(kept?).to be(true)
      expect(a_request(:post, GitHubGraphQL::URL)).not_to have_been_made
    end

    it "reaps nothing when GitHub rate limits the read" do
      stub_repos_answer(github_rate_limited)
      reap

      expect(kept?).to be(true)
    end

    it "reaps nothing when GitHub breaks" do
      stub_repos_answer({ status: 500, body: "something broke" })
      reap

      expect(kept?).to be(true)
    end

    it "reaps nothing when the list comes back empty" do
      stub_repos
      reap

      expect(kept?).to be(true)
    end

    it "reaps nothing when every listed repository is read-only" do
      stub_repos(github_repository(repo, permission: "READ"))
      reap

      expect(kept?).to be(true)
    end

    it "reaps nothing when the page limit cuts the list short" do
      pages = Array.new(Record::GitHub::Client::MAX_PAGES) { github_repos_page(github_repository(repo), more: true) }
      stub_repos_answer(*pages, github_repos_page(github_repository(gone)))
      reap

      expect(kept?).to be(true)
    end

    it "reaps nothing when GitHub sends an answer it cannot read" do
      stub_repos_answer({ body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" } })
      reap

      expect(kept?).to be(true)
    end
  end
end
