# frozen_string_literal: true

RSpec.describe Projects::Jobs::RefreshProjects do
  let(:api) { "https://api.github.com" }
  let(:project) { create(:project, repo:, stars: 3, release: "v1.0.0") }
  let(:project_repo) { Projects::Slice["repos.project_repo"] }
  let(:repo) { "aaronmallen/aaronmallen.me" }

  def failure = sync_state_queries.failure(Blog::Types::SyncName["projects"])
  def html = { body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" } }

  before do
    connect_github_token
    stub_repo(repo, stars: 42)
    stub_release(repo, tag: "v2.0.0")
    project
  end

  def json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def refresh = described_class.new.perform

  def stored(project) = project_repo.by_id(project.id)

  def stub_other(stars: 7, tag: "v3.1.0")
    stub_repo("aaronmallen/other", stars:)
    stub_release("aaronmallen/other", tag:)
  end

  def stub_release(repo, tag: "v1.0.0", response: nil)
    stub_request(:get, "#{api}/repos/#{repo}/releases/latest").to_return(response || json({ tag_name: tag }))
  end

  def stub_repo(repo, stars: 0, response: nil)
    stub_request(:get, "#{api}/repos/#{repo}").to_return(response || json({ full_name: repo, stargazers_count: stars }))
  end

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  describe "a refresh GitHub answers" do
    it "stores the star count and the latest release GitHub reports" do
      refresh

      expect(stored(project)).to have_attributes(stars: 42, release: "v2.0.0")
    end

    it "refreshes every project that names a repository" do
      other = create(:project, repo: "aaronmallen/other", stars: 0, release: nil)
      stub_other
      refresh

      expect(stored(other)).to have_attributes(stars: 7, release: "v3.1.0")
    end

    it "refreshes a project whose url points somewhere other than GitHub" do
      elsewhere = create(:project, repo: "aaronmallen/other", url: "https://gest.aaronmallen.dev")
      stub_other(stars: 9)
      refresh

      expect(stored(elsewhere).stars).to eq(9)
    end

    it "refreshes an archived project" do
      archived = create(:project, :archived, repo: "aaronmallen/other", stars: 1, release: nil)
      stub_other
      refresh

      expect(stored(archived)).to have_attributes(stars: 7, release: "v3.1.0")
    end

    it "leaves a project with no repository alone" do
      loose = create(:project, repo: nil, url: nil, stars: 5)
      refresh

      expect(stored(loose)).to have_attributes(stars: 5, updated_at: loose.updated_at)
    end

    it "writes nothing to a project already up to date" do
      current = create(:project, repo: "aaronmallen/other", stars: 7, release: "v3.1.0")
      stub_other
      refresh

      expect(stored(current).updated_at).to eq(current.updated_at)
    end

    it "clears the failure an earlier refresh left" do
      sync_state_mutations.record_failure(Blog::Types::SyncName["projects"], :rate_limited)
      refresh

      expect(failure).to be_nil
    end
  end

  describe "a project with no releases" do
    before { stub_release(repo, response: { status: 404 }) }

    it "clears the stored release and still stores the star count" do
      refresh

      expect(stored(project)).to have_attributes(stars: 42, release: nil)
    end
  end

  describe "a repository GitHub answers 404 for" do
    before { stub_repo(repo, response: { status: 404 }) }

    it "keeps the stored stars and release" do
      refresh

      expect(stored(project)).to have_attributes(stars: 3, release: "v1.0.0")
    end

    it "never asks for the release of a repository that has gone" do
      refresh

      expect(a_request(:get, "#{api}/repos/#{repo}/releases/latest")).not_to have_been_made
    end

    it "refreshes the other projects" do
      other = create(:project, repo: "aaronmallen/other", stars: 0, release: nil)
      stub_other
      refresh

      expect(stored(other)).to have_attributes(stars: 7, release: "v3.1.0")
    end
  end

  describe "a page that isn't JSON" do
    before do
      stub_repo(repo, response: html)
      stub_release(repo, response: html)
    end

    it "keeps the stored stars and release" do
      refresh

      expect(stored(project)).to have_attributes(stars: 3, release: "v1.0.0")
    end

    it "records no failure" do
      refresh

      expect(failure).to be_nil
    end
  end

  describe "with no GitHub token" do
    before { connect_github(**GitHubCredentials::OAUTH_APP) }

    it "asks GitHub for nothing" do
      refresh

      expect(a_request(:get, "#{api}/repos/#{repo}")).not_to have_been_made
    end

    it "records the refresh that never ran rather than clearing the failure" do
      sync_state_mutations.record_failure(Blog::Types::SyncName["projects"], :rate_limited)
      refresh

      expect(failure).to include(reason: "not_configured")
    end
  end

  describe "when GitHub rate limits the refresh" do
    before { stub_repo(repo, response: github_rate_limited) }

    it "records the rate limit" do
      refresh

      expect(failure).to include(reason: "rate_limited")
    end

    it "keeps the stored stars and release" do
      refresh

      expect(stored(project)).to have_attributes(stars: 3, release: "v1.0.0")
    end
  end

  describe "when GitHub answers with an error" do
    it "records what GitHub answered beside the reason" do
      stub_repo(repo, response: { status: 502 })
      refresh

      expect(failure).to include(message: "GitHub answered 502 for /repos/#{repo}", reason: "github_failed")
    end

    it "records a connection that timed out" do
      stub_request(:get, "#{api}/repos/#{repo}").to_timeout
      refresh

      expect(failure).to include(message: a_string_starting_with("GitHub request to /repos/#{repo} failed: "))
    end

    it "keeps the projects it refreshed before the error" do
      create(:project, repo: "aaronmallen/other")
      stub_repo("aaronmallen/other", response: { status: 500 })
      refresh

      expect(stored(project).stars).to eq(42)
    end
  end
end
