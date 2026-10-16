# frozen_string_literal: true

RSpec.describe Projects::Jobs::RefreshProject do
  let(:project_queries) { Projects::Slice["repos.project_queries"] }
  let(:repo) { "aaronmallen/fresh" }

  def fields(**overrides) = { name: "fresh", visibility: "public", repo:, **overrides }

  def queued = described_class.jobs.map { it.fetch("args") }

  def save(id: nil, **overrides) = Projects::Slice["operations.save_project"].call(fields(**overrides), id:).value!

  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  describe "saving a project", :commits do
    it "queues a fetch for a new project with a repo" do
      project = save

      expect(queued).to eq([[project.id]])
    end

    it "queues nothing for a project with no repo" do
      save(repo: nil, url: nil)

      expect(queued).to be_empty
    end

    it "queues a fetch when an update changes the repo" do
      project = create(:project, repo: "aaronmallen/old")
      save(id: project.id, repo:)

      expect(queued).to eq([[project.id]])
    end

    it "queues nothing when an update keeps the repo" do
      project = create(:project, repo:)
      save(id: project.id, repo:, name: "renamed")

      expect(queued).to be_empty
    end

    it "queues nothing when the save rolls back" do
      Projects::Slice["db.rom"].gateways[:default].connection.transaction(rollback: :always) { save }

      expect(queued).to be_empty
    end
  end

  describe "running the fetch" do
    let(:project) { create(:project, repo:, stars: 0, release: nil) }

    before { connect_github_token }

    def fetch = described_class.new.perform(project.id)

    def stored = project_queries.by_id(project.id)

    it "stores the stars and latest release" do
      stub_github_repo(repo, stars: 42, release: "v2.0.0")
      fetch

      expect(stored).to have_attributes(stars: 42, release: "v2.0.0")
    end

    it "never retries" do
      expect(described_class.get_sidekiq_options["retry"]).to be(false)
    end

    it "leaves the stored stars and the projects sync state alone when GitHub fails", :aggregate_failures do
      Record::Slice["repos.sync_state_mutations"].record_failure(Blog::Types::SyncName["projects"], :rate_limited)
      stub_request(:get, "https://api.github.com/repos/#{repo}").to_return(status: 502)
      fetch

      expect(stored.stars).to eq(0)
      expect(sync_state_queries.failure(Blog::Types::SyncName["projects"])).to include(reason: "rate_limited")
    end

    it "asks GitHub for nothing once the project has lost its repo" do
      loose = create(:project, repo: nil, url: nil)
      described_class.new.perform(loose.id)

      expect(a_request(:get, /api\.github\.com/)).not_to have_been_made
    end
  end
end
