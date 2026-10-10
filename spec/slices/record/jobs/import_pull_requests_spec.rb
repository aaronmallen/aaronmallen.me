# frozen_string_literal: true

RSpec.describe Record::Jobs::ImportPullRequests do
  def day = 24 * 60 * 60

  def failure = Record::Slice["repos.sync_state_queries"].failure(sync)

  def import = described_class.new.perform

  def range(body)
    search_text(body).match(/updated:(\S+)\.\.(\S+)/).captures.map { Time.iso8601(it) }
  end

  def search_text(body) = JSON.parse(body).dig("variables", "query")

  def searched(text) = github_request(GitHubGraphQL::PULL_REQUESTS_QUERY).with { search_text(it.body).include?(text) }

  def stored(number, repo: "aaronmallen/aaronmallen.me")
    Record::Slice["relations.pull_requests"].where(repo:, number:).with(auto_struct: true).one
  end

  def stub_search(*nodes, **) = stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY, github_pull_request_search(*nodes, **))

  def stub_windows(crowded_over: Float::INFINITY)
    stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY) do |request|
      from, to = range(request.body)
      windows << [from, to]
      github_pull_request_search(github_pull_request(from.year), count: to - from > crowded_over ? 1500 : 1)
    end
  end

  def sync = Blog::Types::SyncName["pull_requests"]

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

  def windows = @windows ||= []

  before { connect_github_token }

  describe "which pull requests it imports" do
    it "imports one I opened from a fork into a repo I cannot push to" do
      stub_search(github_pull_request(7, repo: "someone/else"))
      import

      expect(stored(7, repo: "someone/else")).to have_attributes(url: "https://github.com/someone/else/pull/7")
    end

    it "asks GitHub only for pull requests I authored" do
      stub_search
      import

      expect(searched("is:pr author:@me")).to have_been_made
    end

    it "skips a pull request somebody else authored" do
      stub_search(github_pull_request(8, viewerDidAuthor: false))
      import

      expect(stored(8)).to be_nil
    end

    it "keeps the title and description", :aggregate_failures do
      stub_search(github_pull_request(9, title: "Import them", body: "Every one"))
      import

      expect(stored(9)).to have_attributes(title: "Import them", body: "Every one")
    end
  end

  describe "the ready time" do
    let(:created_at) { Time.utc(2026, 10, 1, 12) }
    let(:marked_at) { Time.utc(2026, 10, 2, 12) }

    it "stores the created time for one opened as ready" do
      stub_search(github_pull_request(1, created_at:))
      import

      expect(stored(1).ready_at).to eq(created_at)
    end

    it "stores no ready time for a draft" do
      stub_search(github_pull_request(1, created_at:, isDraft: true))
      import

      expect(stored(1).ready_at).to be_nil
    end

    it "stores the time a draft was marked ready once it is" do
      stub_search(github_pull_request(1, created_at:, isDraft: true))
      import
      stub_search(github_pull_request(1, created_at:, ready_at: marked_at))
      import

      expect(stored(1).ready_at).to eq(marked_at)
    end
  end

  describe "how it ended" do
    let(:ended_at) { Time.utc(2026, 10, 3, 12) }

    it "stores a merged time and no closed time for a merged one" do
      ended = github_time(ended_at)
      stub_search(github_pull_request(1, state: "MERGED", mergedAt: ended, closedAt: ended))
      import

      expect(stored(1)).to have_attributes(merged_at: ended_at, closed_at: nil)
    end

    it "stores a closed time for one closed without a merge" do
      stub_search(github_pull_request(1, state: "CLOSED", closedAt: github_time(ended_at)))
      import

      expect(stored(1)).to have_attributes(merged_at: nil, closed_at: ended_at)
    end

    it "drops the closed time once it is reopened" do
      stub_search(github_pull_request(1, state: "CLOSED", closedAt: github_time(ended_at)))
      import
      stub_search(github_pull_request(1, closedAt: github_time(ended_at)))
      import

      expect(stored(1).closed_at).to be_nil
    end
  end

  describe "the first import" do
    it "reads back to the start of GitHub" do
      stub_search
      import

      expect(searched("updated:2008-01-01T00:00:00Z..")).to have_been_made
    end

    it "splits my history into windows small enough for search to hold", :aggregate_failures do
      stub_windows(crowded_over: 10 * 365 * day)
      import

      expect(windows.size).to eq(3)
      expect(Record::Slice["relations.pull_requests"].count).to eq(2)
    end

    it "follows a window to its next page", :aggregate_failures do
      stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY, github_pull_request_search(github_pull_request(1), more: true),
                  github_pull_request_search(github_pull_request(2)))
      import

      expect(stored(1)).not_to be_nil
      expect(stored(2)).not_to be_nil
    end
  end

  describe "a later import" do
    before do
      stub_search(github_pull_request(1))
      import
    end

    it "reads from a day before the last import" do
      stub_windows
      import

      expect(windows.map(&:first)).to contain_exactly(be_within(5).of(Time.now - day))
    end

    it "picks up a title and description I edited on GitHub" do
      stub_search(github_pull_request(1, title: "Import them all", body: "Edited"))
      import

      expect(stored(1)).to have_attributes(title: "Import them all", body: "Edited")
    end

    it "keeps one row for a pull request it reads again" do
      import

      expect(Record::Slice["relations.pull_requests"].count).to eq(1)
    end
  end

  describe "reporting the outcome" do
    it "never retries a failed run" do
      expect(described_class.get_sidekiq_options["retry"]).to be(false)
    end

    it "clears the failure once a run finishes" do
      sync_state_mutations.record_failure(sync, :rate_limited)
      stub_search
      import

      expect(failure).to be_nil
    end

    it "records a rate limit" do
      stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY, github_rate_limited)
      import

      expect(failure).to include(reason: "rate_limited")
    end

    it "records what GitHub answered beside the reason" do
      stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY, { status: 502 })
      import

      expect(failure).to include(message: "GitHub answered 502 for GraphQL", reason: "github_failed")
    end

    it "stores nothing from a run that fails part way" do
      stub_github(GitHubGraphQL::PULL_REQUESTS_QUERY, github_pull_request_search(github_pull_request(1), more: true),
                  { status: 502 })
      import

      expect(stored(1)).to be_nil
    end
  end

  describe "with no GitHub token" do
    before { disconnect_github }

    it "records the sync that never ran", :aggregate_failures do
      import

      expect(failure).to include(reason: "not_configured")
      expect(a_request(:post, GitHubGraphQL::URL)).not_to have_been_made
    end
  end

  describe "when another run is already going" do
    let(:connection) { Record::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }
    let(:lock) { Blog::DB::Relation.lock_key(Record::Repos::PullRequestMutations::IMPORT_LOCK) }

    before { elsewhere.get(Sequel.function(:pg_try_advisory_lock, lock)) }

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock and reports nothing", :aggregate_failures do
      sync_state_mutations.record_failure(sync, :rate_limited)
      import

      expect(github_request(GitHubGraphQL::PULL_REQUESTS_QUERY)).not_to have_been_made
      expect(failure).to include(reason: "rate_limited")
    end
  end
end
