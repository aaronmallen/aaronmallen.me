# frozen_string_literal: true

RSpec.describe Record::Jobs::ImportCommits do
  include Spec::DB::FactoryHelper.new(:record)

  let(:commit_repo) { Record::Slice["repos.commit_repo"] }
  let(:repo) { "aaronmallen/aaronmallen.me" }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }

  before do
    connect_github_token
    stub_repos(github_repository(repo))
  end

  def commits_sync = Record::Repos::SyncStateRepo::COMMITS

  def day = 24 * 60 * 60

  def failure = sync_state_repo.failure(commits_sync)

  def import = described_class.new.perform

  def queued = Record::Jobs::BackfillRepoCommits.jobs.map { it["args"].first }

  def stall(name, at: Time.now - (3 * 60 * 60))
    Record::Slice["relations.sync_states"].of("backfill", repo: name).update(updated_at: at)
  end

  def stored(sha) = Record::Slice["relations.commits"].with_sha(sha).with(auto_struct: true).one

  def stored_at(time) = create(:commit, created_at: time, updated_at: time)

  def stub_repos(*repositories, **) = stub_github(GitHubGraphQL::REPOS_QUERY, github_repos_page(*repositories, **))

  def stub_repos_answer(*responses) = stub_github(GitHubGraphQL::REPOS_QUERY, *responses)

  describe "an empty commits table" do
    def long_quiet = github_repository("aaronmallen/one", pushed_at: "2015-01-01T00:00:00Z")

    it "queues a walk for every repository, however long ago it was pushed" do
      stub_repos(long_quiet, github_repository(repo, pushed_at: nil))
      import

      expect(queued).to eq(["aaronmallen/one", repo])
    end

    it "follows the listing to the next page" do
      stub_repos_answer(github_repos_page(long_quiet, more: true), github_repos_page(github_repository(repo)))
      import

      expect(queued).to eq(["aaronmallen/one", repo])
    end
  end

  describe "the walks it queues" do
    it "starts each walk at the run's own clock", :aggregate_failures do
      import

      expect(commit_repo.backfilled_to(repo)).to be_within(5).of(Time.now)
      expect(Time.iso8601(Record::Jobs::BackfillRepoCommits.jobs.first["args"].last)).to be_within(5).of(Time.now)
    end

    it "reads no commits itself, so the scheduled run stays short" do
      import

      expect(github_request(GitHubGraphQL::REFS_QUERY)).not_to have_been_made
    end

    it "asks for the repositories I own, collaborate on and reach through an organization", :aggregate_failures do
      import

      expect(github_request("affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]")).to have_been_made
      expect(github_request("ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]")).to have_been_made
    end

    it "skips a repository I can't push to" do
      stub_repos(github_repository("someone/else", permission: "READ"))
      import

      expect(queued).to be_empty
    end

    it "queues a repository I maintain without owning" do
      stub_repos(github_repository("org/one", permission: "MAINTAIN"))
      import

      expect(queued).to eq(["org/one"])
    end

    it "stops at the page limit" do
      stub_repos(github_repository(repo), more: true)
      import

      expect(github_request(GitHubGraphQL::REPOS_QUERY)).to have_been_made.times(Record::GitHub::Client::MAX_PAGES)
    end

    it "reads an answer GitHub does not send as JSON as no repositories" do
      stub_repos_answer({ body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" } })
      import

      expect(queued).to be_empty
    end
  end

  describe "the window, with commits stored" do
    before { stored_at(Time.now - (3 * day)) }

    it "queues a repository pushed since a day before the newest stored commit" do
      stub_repos(github_repository(repo, pushed_at: Time.now - (3 * day) - 3600))
      import

      expect(queued).to eq([repo])
    end

    it "skips a repository last pushed before that" do
      stub_repos(github_repository(repo, pushed_at: Time.now - (5 * day)))
      import

      expect(queued).to be_empty
    end

    it "reads the floor off the newest stored row, not the oldest" do
      stored_at(Time.now - (40 * day))
      stub_repos(github_repository(repo, pushed_at: Time.now - (10 * day)))
      import

      expect(queued).to be_empty
    end

    it "skips a repository nobody has ever pushed to" do
      stub_repos(github_repository(repo, pushed_at: nil))
      import

      expect(queued).to be_empty
    end

    it "stops at the first repository outside the window, since GitHub sorts by push" do
      old = github_repository("old/one", pushed_at: "2020-01-01T00:00:00Z")
      stub_repos_answer(github_repos_page(github_repository(repo), old, more: true),
                        github_repos_page(github_repository("aaronmallen/one")))
      import

      expect(queued).to eq([repo])
    end

    it "queues a repository with a recorded failure, pushed or not" do
      stub_repos(github_repository(repo, pushed_at: Time.now - (40 * day)))
      sync_state_repo.record_failure(commits_sync, :github_failed, repo:)
      import

      expect(queued).to eq([repo])
    end

    it "queues a repository pushed and failed once" do
      sync_state_repo.record_failure(commits_sync, :github_failed, repo:)
      import

      expect(queued).to eq([repo])
    end

    it "queues nothing for a failure that names no repository" do
      stub_repos(github_repository(repo, pushed_at: Time.now - (40 * day)))
      sync_state_repo.record_failure(commits_sync, :rate_limited)
      import

      expect(queued).to be_empty
    end
  end

  describe "a repository whose walk is going" do
    before { commit_repo.record_backfilled_to(repo, at: Time.now - 600) }

    it "queues no second walk", :aggregate_failures do
      sync_state_repo.record_failure(commits_sync, :github_failed, repo:)
      import

      expect(queued).to be_empty
      expect(commit_repo.backfilled_to(repo)).to be_within(5).of(Time.now - 600)
    end

    it "starts the walk again once it has stalled, pushed or not", :aggregate_failures do
      stub_repos(github_repository(repo, pushed_at: nil))
      stall(repo)
      import

      expect(queued).to eq([repo])
      expect(commit_repo.backfilled_to(repo)).to be_within(5).of(Time.now)
    end
  end

  describe "a run and the walks it queued" do
    let(:history) do
      {
        repo => [written("a", 3600), written("b", 9 * day), written("c", 30 * day)],
        "aaronmallen/one" => [written("d", 400 * day)],
      }
    end

    before do
      stub_github_viewer
      stub_github(GitHubGraphQL::REFS_QUERY) { |request| history_page(JSON.parse(request.body)["variables"]) }
    end

    def all_stored = Record::Slice["relations.commits"].pluck(:sha).sort

    def history_page(variables)
      name = "#{variables['owner']}/#{variables['name']}"
      since, before = variables.values_at("since", "until").map { it && Time.iso8601(it) }
      open = history.fetch(name, []).select { inside?(Time.iso8601(it[:committedDate]), since, before) }

      github_refs_page(github_branch("main", *open.first(1), more: open.size > 1))
    end

    def inside?(time, since, before) = (since.nil? || time >= since) && (before.nil? || time <= before)

    def run_through
      import
      Record::Jobs::BackfillRepoCommits.drain
    end

    def written(letter, ago) = github_commit(letter * 40, at: Time.now - ago)

    it "fills an empty table with every repository's whole history", :aggregate_failures do
      stub_repos(github_repository(repo), github_repository("aaronmallen/one", pushed_at: Time.now - (300 * day)))
      run_through

      expect(all_stored).to eq(%w[a b c d].map { it * 40 })
      expect(commit_repo.walks).to be_empty
    end

    it "leaves every repository a forward edge a day before its walk began" do
      run_through

      expect(commit_repo.synced_through(repo)).to be_within(5).of(Time.now - day)
    end

    it "reads a repository again only down to its forward edge" do
      run_through
      edge = commit_repo.synced_through(repo).utc.iso8601
      run_through

      expect(github_request(GitHubGraphQL::REFS_QUERY, since: edge)).to have_been_made.at_least_once
    end

    it "reads a commit twice into one row" do
      2.times { run_through }

      expect(Record::Slice["relations.commits"].count).to eq(3)
    end

    it "looks up the commits it already holds in one query for a page of branches" do
      branches = [github_branch("main", *%w[a b c].map { written(it, 3600) }),
                  github_branch("topic", *%w[d e].map { written(it, 3600) })]
      stub_github(GitHubGraphQL::REFS_QUERY, github_refs_page(*branches))

      expect(counting { run_through }.grep(/\ASELECT "commits"."sha" FROM "commits"/).size).to eq(1)
    end

    describe "after an earlier run stored commits" do
      before { stored_at(Time.now - 600) }

      it "reads a repository made since then, with commits dated weeks before it" do
        stub_repos(github_repository("aaronmallen/one", pushed_at: Time.now - 300))
        history["aaronmallen/one"] = [written("e", 21 * day), written("f", 35 * day)]
        run_through

        expect(%w[e f].map { stored(it * 40) }).to all(have_attributes(repo: "aaronmallen/one"))
      end

      it "fills a repository whose walk failed, though nobody pushed to it", :aggregate_failures do
        stub_repos(github_repository(repo, pushed_at: Time.now - (40 * day)))
        sync_state_repo.record_failure(commits_sync, :github_failed, repo:)
        run_through

        expect(%w[a b c].map { stored(it * 40) }).to all(have_attributes(repo:))
        expect(sync_state_repo.failure(commits_sync, repo:)).to be_nil
      end
    end
  end

  describe "a walk that fails, and the run after it" do
    let(:old_commit) { github_commit("a" * 40, at: Time.now - (60 * day)) }

    before do
      stub_github_viewer
      stored_at(Time.now - 600)
      stub_repos(github_repository(repo))
      stub_github(GitHubGraphQL::REFS_QUERY, { status: 502 }, github_refs_page(github_branch("main", old_commit)))
      import
      Record::Jobs::BackfillRepoCommits.drain
      stub_repos(github_repository(repo, pushed_at: Time.now - (40 * day)))
    end

    it "queues the repository again for its failure" do
      import

      expect(queued).to eq([repo])
    end

    it "has the missing commits once that walk ends", :aggregate_failures do
      import
      Record::Jobs::BackfillRepoCommits.drain

      expect(stored("a" * 40)).to have_attributes(repo:)
      expect(sync_state_repo.failure(commits_sync, repo:)).to be_nil
    end
  end

  describe "reporting the outcome" do
    it "clears the failure once a run finishes" do
      sync_state_repo.record_failure(commits_sync, :rate_limited)
      import

      expect(failure).to be_nil
    end

    it "records a rate limit" do
      stub_repos_answer(github_rate_limited)
      import

      expect(failure).to include(reason: "rate_limited")
    end

    it "records what GitHub answered beside the reason" do
      stub_repos_answer({ status: 502 })
      import

      expect(failure).to include(message: "GitHub answered 502 for GraphQL", reason: "github_failed")
    end

    it "says the request failed when the connection times out" do
      stub_request(:post, GitHubGraphQL::URL).to_timeout
      import

      expect(failure[:message]).to start_with("GitHub GraphQL request failed: ")
    end

    it "keeps the token out of the message" do
      stub_repos_answer({ status: 500 })
      import

      expect(failure[:message]).not_to include("ghp_token")
    end

    it "queues nothing when GitHub fails" do
      sync_state_repo.record_failure(commits_sync, :github_failed, repo:)
      stub_repos_answer(github_rate_limited)
      import

      expect(queued).to be_empty
    end

    it "counts each failed run" do
      stub_repos_answer({ status: 502 })
      2.times { import }

      expect(failure).to include(count: 2)
    end
  end

  describe "with no GitHub token" do
    before { disconnect_github }

    it "records the sync that never ran" do
      import

      expect(failure).to include(reason: "not_configured")
    end

    it "asks GitHub for nothing and queues nothing", :aggregate_failures do
      import

      expect(a_request(:post, GitHubGraphQL::URL)).not_to have_been_made
      expect(queued).to be_empty
    end
  end

  describe "when another run is already going" do
    let(:connection) { Record::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }

    before { elsewhere.get(Sequel.function(:pg_try_advisory_lock, Record::Repos::CommitRepo::IMPORT_LOCK)) }

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock" do
      import

      expect(github_request(GitHubGraphQL::REPOS_QUERY)).not_to have_been_made
    end

    it "reports nothing about a run it never made" do
      sync_state_repo.record_failure(commits_sync, :rate_limited)
      import

      expect(failure).to include(reason: "rate_limited")
    end
  end
end
