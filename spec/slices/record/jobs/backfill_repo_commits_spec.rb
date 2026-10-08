# frozen_string_literal: true

RSpec.describe Record::Jobs::BackfillRepoCommits do
  include Spec::DB::FactoryHelper.new(:record)

  let(:clock) { Time.utc(2026, 8, 20, 12) }
  let(:edge) { Time.utc(2026, 8, 18, 15) }
  let(:repo) { "aaronmallen/aaronmallen.me" }

  before do
    connect_github_token
    stub_github_viewer
    commit_mutations.record_backfilled_to(repo, at: edge)
  end

  def commit(sha, at: "2026-08-10T14:30:00Z", message: "lib: an older commit", **)
    github_commit(sha, at:, message:, **)
  end

  def commit_mutations = Record::Slice["repos.commit_mutations"]
  def commit_queries = Record::Slice["repos.commit_queries"]

  def commits_sync = Blog::Types::SyncName["commits"]

  def day = Record::Operations::PlanCommitWalk::OVERLAP

  def empty_step = Record::Operations::PlanCommitWalk::EMPTY_STEP

  def failure = sync_state_queries.failure(commits_sync, repo:)

  def next_chunk
    described_class.clear
    walk
  end

  def old_sha = "b" * 40

  def scheduled = described_class.jobs.map { [it["args"], it["at"]] }

  def sha = "a" * 40

  def stored(sha) = Record::Slice["relations.commits"].with_sha(sha).with(auto_struct: true).one

  def stub_refs(*branches, **) = stub_github(GitHubGraphQL::REFS_QUERY, github_refs_page(*branches, **))

  def stub_refs_answer(*responses) = stub_github(GitHubGraphQL::REFS_QUERY, *responses)

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]
  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  def walk(name = repo) = described_class.new.perform(name, clock.iso8601)

  def walking = [[[repo, clock.iso8601], nil]]

  describe "a chunk of history" do
    before { stub_refs(github_branch("main", commit(sha), more: true)) }

    it "stores the commit on the branch it was read from" do
      walk

      expect(stored(sha)).to have_attributes(branch: "main", message: "lib: an older commit", repo:)
    end

    it "stores the additions and deletions GitHub reports" do
      walk

      expect(stored(sha)).to have_attributes(additions: 12, deletions: 3)
    end

    it "stores the author date in Chicago local time" do
      walk

      expect(stored(sha)).to have_attributes(commit_date: Date.new(2026, 8, 10), commit_time: have_attributes(hour: 9))
    end

    it "stores the day a rebased commit was written, not the day it was committed" do
      stub_refs(github_branch("main", commit(sha, at: "2026-07-21T15:20:13Z", committed: "2026-08-10T04:49:21Z"),
                              more: true))
      walk

      expect(stored(sha).commit_date).to eq(Date.new(2026, 7, 21))
    end

    it "stores the body GitHub sends, not only the subject" do
      stub_refs(github_branch("main", commit(sha, message: "lib: an older commit\n\nand say why\n"), more: true))
      walk

      expect(stored(sha).message).to eq("lib: an older commit\n\nand say why")
    end

    it "asks GitHub for the owner's node id once and filters the history by it", :aggregate_failures do
      walk
      next_chunk

      expect(github_request(GitHubGraphQL::VIEWER_QUERY)).to have_been_made.once
      expect(github_request(GitHubGraphQL::REFS_QUERY, author: GitHubGraphQL::VIEWER_ID)).to have_been_made.twice
    end

    it "sends the token to GraphQL as a JSON bearer request" do
      walk

      expect(a_request(:post, GitHubGraphQL::URL)
        .with(headers: { "Authorization" => "bearer ghp_token", "Content-Type" => "application/json" }))
        .to have_been_made.at_least_once
    end

    it "asks for no other repository" do
      walk

      expect(github_request(GitHubGraphQL::REPOS_QUERY)).not_to have_been_made
    end

    it "asks GitHub only for commits older than the back edge" do
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY, until: edge.utc.iso8601)).to have_been_made
    end

    it "reads one page per branch, so a lost chunk costs one query" do
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY)).to have_been_made.once
    end

    it "moves the back edge to the oldest commit it read" do
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(Time.utc(2026, 8, 10, 14, 30))
    end

    it "queues the next chunk for the same repository, with the walk's clock" do
      walk

      expect(scheduled).to eq(walking)
    end

    it "leaves the forward edge alone until the walk is done" do
      walk

      expect(commit_queries.synced_through(repo)).to be_nil
    end

    it "walks back from the edge the last chunk left" do
      walk
      next_chunk

      expect(github_request(GitHubGraphQL::REFS_QUERY, until: "2026-08-10T14:30:00Z")).to have_been_made
    end

    it "clears the failure the repository last recorded, and only that one", :aggregate_failures do
      sync_state_mutations.record_failure(commits_sync, :github_failed, repo:)
      sync_state_mutations.record_failure(commits_sync, :github_failed, repo: "aaronmallen/other")
      walk

      expect(failure).to be_nil
      expect(sync_state_queries.failure(commits_sync, repo: "aaronmallen/other")).to include(reason: "github_failed")
    end

    it "marks the walk as still going" do
      Record::Slice["relations.sync_states"].of_kind("backfill").update(updated_at: Time.now - (3 * day))
      walk

      expect(commit_queries.walks[repo]).to be_within(5).of(Time.now)
    end
  end

  describe "a repository it has never read" do
    before { stub_refs(github_branch("main", commit(sha))) }

    it "reads with no lower bound, to the start of history" do
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY, since: nil)).to have_been_made
    end
  end

  describe "a repository it has read before" do
    let(:floor) { Time.utc(2026, 8, 1, 9) }

    before { commit_mutations.record_synced_through(repo, at: floor) }

    it "reads back only to the forward edge" do
      stub_refs(github_branch("main", commit(sha)))
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY, since: floor.iso8601)).to have_been_made
    end

    it "ends the walk once a step would pass the forward edge", :aggregate_failures do
      stub_refs(unanswered_github_branch("main"))
      commit_mutations.record_backfilled_to(repo, at: floor + empty_step)
      walk

      expect(commit_queries.backfilled_to(repo)).to be_nil
      expect(commit_queries.synced_through(repo)).to eq(clock - day)
    end

    it "keeps stepping while the forward edge is still below" do
      stub_refs(unanswered_github_branch("main"))
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(edge - empty_step)
    end
  end

  describe "a branch pushed days after its commits" do
    let(:floor) { Time.utc(2026, 8, 12, 9) }

    before do
      commit_mutations.record_synced_through(repo, at: floor)
      create(:commit, sha: old_sha, branch: "main")
    end

    def late_sha = "c" * 40

    def stub_late_push(*below, remaining: 4999)
      above = github_refs_page(github_branch("main", commit(sha, at: "2026-08-15T09:00:00Z")), remaining:)
      stub_github(GitHubGraphQL::REFS_QUERY) do |request|
        JSON.parse(request.body).dig("variables", "since") ? above : below.shift
      end
    end

    def topic(*commits, more: false) = github_branch("topic", *commits, more:)

    def under_floor(*branches) = github_refs_page(github_branch("main", commit(old_sha)), *branches)

    it "stores a commit dated before the floor that GitHub lists under it", :aggregate_failures do
      stub_late_push(under_floor(topic(commit(late_sha), commit(old_sha), more: true)))
      walk

      expect(stored(late_sha)).to have_attributes(branch: "topic", repo:)
      expect(github_request(GitHubGraphQL::REFS_QUERY, since: nil, until: floor.iso8601)).to have_been_made
    end

    it "ends the walk once every branch under the floor meets a commit it already has", :aggregate_failures do
      stub_late_push(under_floor(topic(commit(late_sha), commit(old_sha), more: true)))
      walk

      expect(commit_queries.backfilled_to(repo)).to be_nil
      expect(commit_queries.synced_through(repo)).to eq(clock - day)
      expect(scheduled).to be_empty
    end

    it "keeps reading under the floor while a branch has only new commits", :aggregate_failures do
      stub_late_push(under_floor(topic(commit(late_sha, at: "2026-08-05T09:00:00Z"), more: true)))
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(Time.utc(2026, 8, 5, 9))
      expect(commit_queries.synced_through(repo)).to eq(floor)
      expect(scheduled).to eq(walking)
    end

    describe "the chunk after it" do
      let(:deeper) { "e" * 40 }

      before do
        first = under_floor(topic(commit(late_sha, at: "2026-08-05T09:00:00Z"), more: true))
        stub_late_push(first, under_floor(topic(commit(deeper, at: "2026-08-02T09:00:00Z"), commit(old_sha))))
        walk
        next_chunk
      end

      it "reads on from the new back edge with no lower bound" do
        expect(github_request(GitHubGraphQL::REFS_QUERY, since: nil, until: "2026-08-05T09:00:00Z")).to have_been_made
      end

      it "stores what it finds there" do
        expect(stored(deeper)).to have_attributes(branch: "topic")
      end
    end

    it "resumes under the floor after GitHub rate limits that read" do
      stub_late_push(github_rate_limited, under_floor(topic(commit(late_sha), commit(old_sha))))
      walk
      next_chunk

      expect(stored(late_sha)).not_to be_nil
    end

    it "waits for the reset before it reads under the floor when the read above left too few", :aggregate_failures do
      stub_late_push(under_floor(topic(commit(late_sha))), remaining: Record::Operations::BackfillRepoCommits::RESERVE)
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY, since: nil)).not_to have_been_made
      expect(commit_queries.backfilled_to(repo)).to eq(floor)
      expect(scheduled).to contain_exactly([[repo, clock.iso8601], be_within(5).of(Time.now.to_f + 1800)])
    end
  end

  describe "reaching the end of what it has to read" do
    before { stub_refs(github_branch("main", commit(sha))) }

    it "moves the forward edge to a day before the walk began" do
      walk

      expect(commit_queries.synced_through(repo)).to eq(clock - day)
    end

    it "ends the walk and queues no further chunk", :aggregate_failures do
      walk

      expect(commit_queries.backfilled_to(repo)).to be_nil
      expect(scheduled).to be_empty
    end

    it "asks GitHub for nothing once the walk has ended" do
      2.times { walk }

      expect(github_request(GitHubGraphQL::REFS_QUERY)).to have_been_made.once
    end

    it "leaves every other repository alone" do
      walk

      expect(commit_queries.synced_through("aaronmallen/other")).to be_nil
    end
  end

  describe "a chunk whose commits all share the edge's second" do
    before { stub_refs(github_branch("main", commit(sha, at: edge), more: true)) }

    it "moves the edge down a second anyway" do
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(edge - 1)
    end
  end

  describe "a rebased commit last on a cut page" do
    let(:committed) { "2026-08-12T14:30:00Z" }

    before do
      history = [
        commit("d" * 40, at: "2026-08-15T14:30:00Z"),
        commit(sha, at: "2026-08-01T14:30:00Z", committed:),
        commit(between_sha, at: "2026-08-06T14:30:00Z"),
      ]
      stub_github(GitHubGraphQL::REFS_QUERY) do |request|
        cutoff = Time.iso8601(JSON.parse(request.body).dig("variables", "until"))
        open = history.select { Time.iso8601(it[:committedDate]) <= cutoff }
        github_refs_page(github_branch("main", *open.first(2), more: open.size > 2))
      end
    end

    def between_sha = "c" * 40

    it "moves the back edge to the date the commit was committed, which GitHub filters history on" do
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(Time.iso8601(committed))
    end

    it "still reads, in the next chunk, a commit committed between the two dates" do
      walk
      next_chunk

      expect(stored(between_sha)).not_to be_nil
    end
  end

  describe "a branch whose page came back empty" do
    before { stub_refs(github_branch("main", more: true)) }

    it "queues another chunk" do
      walk

      expect(scheduled).to eq(walking)
    end

    it "moves the back edge down an hour, so the walk doesn't crawl a second at a time" do
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(edge - empty_step)
    end
  end

  describe "a branch GitHub sent no history for" do
    before { stub_refs(unanswered_github_branch("main")) }

    it "keeps walking, rather than writing off history nobody read", :aggregate_failures do
      walk

      expect(commit_queries.synced_through(repo)).to be_nil
      expect(scheduled).to eq(walking)
    end
  end

  describe "a repository walked back to the day it was made" do
    before { stub_refs(unanswered_github_branch("main"), created_at: edge - empty_step) }

    it "stops asking for history that cannot exist", :aggregate_failures do
      2.times { walk }

      expect(scheduled).to be_empty
      expect(github_request(GitHubGraphQL::REFS_QUERY)).to have_been_made.once
    end

    it "ends the walk and moves the forward edge", :aggregate_failures do
      walk

      expect(commit_queries.backfilled_to(repo)).to be_nil
      expect(commit_queries.synced_through(repo)).to eq(clock - day)
    end

    it "records why it stopped, naming the branch it never read" do
      walk

      expect(failure)
        .to include(reason: "repository_start", message: "main still unread", since: be_within(5).of(Time.now))
    end

    it "stores what it did read on the way" do
      stub_refs(github_branch("main", commit(sha)), unanswered_github_branch("topic"), created_at: edge - empty_step)
      walk

      expect(stored(sha)).not_to be_nil
    end

    it "starts the failure afresh rather than counting an earlier one into it" do
      sync_state_mutations.record_failure(commits_sync, :github_failed, repo:)
      walk

      expect(failure).to include(count: 1, reason: "repository_start")
    end
  end

  describe "a repository still above the day it was made" do
    before { stub_refs(unanswered_github_branch("main"), created_at: "2019-04-02T08:15:00Z") }

    it "keeps walking and records nothing", :aggregate_failures do
      walk

      expect(scheduled).to eq(walking)
      expect(failure).to be_nil
    end
  end

  describe "a repository with two branches" do
    it "stops at the shallowest branch, so the deeper one is not walked past" do
      shallow = "2026-08-15T09:00:00Z"
      stub_refs(github_branch("main", commit(sha), more: true),
                github_branch("topic", commit(old_sha, at: shallow), more: true))
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(Time.iso8601(shallow))
    end

    it "stores a commit found on two branches once, under the default branch", :aggregate_failures do
      stub_refs(github_branch("topic", commit(sha)), github_branch("trunk", commit(sha)), default_branch: "trunk")
      walk

      expect(Record::Slice["relations.commits"].count).to eq(1)
      expect(stored(sha).branch).to eq("trunk")
    end

    it "stores a commit under the first branch it came on when the repository names no default branch" do
      stub_refs(github_branch("topic", commit(sha)), github_branch("main", commit(sha)), default_branch: nil)
      walk

      expect(stored(sha).branch).to eq("topic")
    end

    it "follows the branch listing past its first page with the cursor GitHub sent", :aggregate_failures do
      first = github_refs_page(github_branch("main", commit(sha)), more: true)
      stub_refs_answer(first, github_refs_page(github_branch("topic", commit(old_sha))))
      walk

      expect(stored(old_sha)).to have_attributes(branch: "topic")
      expect(github_request(GitHubGraphQL::REFS_QUERY, cursor: "refs-page-2")).to have_been_made
    end
  end

  describe "a commit read twice" do
    before { stub_refs(github_branch("main", commit(sha))) }

    it "leaves one row" do
      walk
      commit_mutations.record_backfilled_to(repo, at: edge)
      walk

      expect(Record::Slice["relations.commits"].count).to eq(1)
    end

    it "restates the message GitHub sends now, and keeps the branch that first claimed it", :aggregate_failures do
      create(:commit, sha:, branch: "topic", message: "lib: an older commit")
      stub_refs(github_branch("main", commit(sha, message: "lib: an older commit\n\nand say why")))
      walk

      expect(stored(sha)).to have_attributes(branch: "topic", message: "lib: an older commit\n\nand say why")
    end
  end

  describe "a commit that closes an issue a task came from" do
    let(:task) { tasks_create(:task) }

    before { tasks_create(:task_source, task_id: task.id, url: "https://github.com/#{repo}/issues/42") }

    def claude = "Co-Authored-By: Claude Opus 5.5 <noreply@example.com>"

    def contributors = Tasks::Slice["relations.task_contributors"].pluck(:task_id, :kind, :agent, :model)

    def import(message)
      stub_refs(github_branch("main", commit(sha, message:)))
      walk
      Tasks::Jobs::CreditAgents.drain
    end

    def tasks_create(name, **) = Spec::DB::Factories[:tasks].create(name, **)

    it "adds the agent and model the trailer names to the task" do
      import("app: credit the agent\n\n#{claude}\n\nCloses #42")

      expect(contributors).to contain_exactly([task.id, "agent", "claude-code", "claude-opus-5-5"])
    end

    it "reads the trailer key in any case" do
      import("app: credit the agent\n\nco-authored-by: Claude Opus 5.5 <noreply@example.com>\n\nCloses #42")

      expect(contributors).to contain_exactly([task.id, "agent", "claude-code", "claude-opus-5-5"])
    end

    it "adds no agent when no trailer names one" do
      import("app: credit nobody\n\nCloses #42")

      expect(contributors).to be_empty
    end

    it "adds no agent for a human co-author or a trailer that names no model" do
      trailers = ["Co-Authored-By: Pat Doe <pat@example.com>", "Co-Authored-By: Claude <noreply@example.com>"]
      import("app: credit nobody\n\n#{trailers.join("\n")}\n\nCloses #42")

      expect(contributors).to be_empty
    end

    it "adds no agent when the commit closes no issue" do
      import("app: credit nobody\n\n#{claude}\n\nSee #42")

      expect(contributors).to be_empty
    end

    it "changes nothing for an issue no task came from" do
      import("app: credit nobody\n\n#{claude}\n\nCloses #43")

      expect(contributors).to be_empty
    end

    it "changes nothing for the same issue number in another repository" do
      Tasks::Slice["relations.task_sources"].update(url: "https://github.com/aaronmallen/other/issues/42")
      import("app: credit nobody\n\n#{claude}\n\nCloses #42")

      expect(contributors).to be_empty
    end

    it "adds the contributor once when it imports the same commit twice" do
      import("app: credit the agent\n\n#{claude}\n\nCloses #42")
      commit_mutations.record_backfilled_to(repo, at: edge)
      import("app: credit the agent\n\n#{claude}\n\nCloses #42")

      expect(contributors.size).to eq(1)
    end

    it "adds the contributor once when two commits name it" do
      stub_refs(github_branch("main", commit(sha, message: "app: one\n\n#{claude}\n\nCloses #42"),
                              commit(old_sha, message: "app: two\n\n#{claude}\n\nCloses #42")))
      walk
      Tasks::Jobs::CreditAgents.drain

      expect(contributors.size).to eq(1)
    end

    it "keeps off a contributor the owner removed when it reads the commit again" do
      import("app: credit the agent\n\n#{claude}\n\nCloses #42")
      Tasks::Slice["relations.task_contributors"].delete
      commit_mutations.record_backfilled_to(repo, at: edge)
      import("app: credit the agent\n\n#{claude}\n\nCloses #42")

      expect(contributors).to be_empty
    end
  end

  describe "a repository GitHub cannot give" do
    it "stores nothing from an empty repository, and ends the walk", :aggregate_failures do
      stub_refs
      walk

      expect(Record::Slice["relations.commits"].count).to eq(0)
      expect(commit_queries.backfilled_to(repo)).to be_nil
    end

    %w[NOT_FOUND FORBIDDEN].each do |type|
      it "stores nothing and records no failure for a #{type} repository", :aggregate_failures do
        stub_refs_answer(github_errors(type, data: { rateLimit: github_rate_limit, repository: nil }))
        walk

        expect(Record::Slice["relations.commits"].count).to eq(0)
        expect(failure).to be_nil
      end
    end

    it "keeps what it read from a branch listing that goes mid-read" do
      first = github_refs_page(github_branch("main", commit(sha)), more: true)
      stub_refs_answer(first, github_errors("NOT_FOUND", "Could not resolve to a Repository"))
      walk

      expect(stored(sha)).not_to be_nil
    end

    it "reads an answer GitHub does not send as JSON as an empty repository" do
      stub_refs_answer({ body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" } })
      walk

      expect(Record::Slice["relations.commits"].count).to eq(0)
    end
  end

  describe "the point reserve" do
    before { stub_refs(github_branch("main", commit(sha), more: true), remaining: reserve - 1) }

    def reserve = Record::Operations::BackfillRepoCommits::RESERVE

    it "reads once, then stops while the points are under the reserve", :aggregate_failures do
      walk
      moved = commit_queries.backfilled_to(repo)
      next_chunk

      expect(github_request(GitHubGraphQL::REFS_QUERY)).to have_been_made.once
      expect(commit_queries.backfilled_to(repo)).to eq(moved)
    end

    it "keeps the last budget it saw when GitHub reports none" do
      low = github_refs_page(github_branch("main", commit(sha), more: true), more: true, remaining: reserve - 1)
      stub_refs_answer(low, github_json(data: { rateLimit: {}, repository: nil }))
      walk
      next_chunk

      expect(github_request(GitHubGraphQL::REFS_QUERY)).to have_been_made.twice
    end

    it "queues itself again for when the points reset" do
      walk
      next_chunk

      expect(scheduled).to contain_exactly([[repo, clock.iso8601], be_within(5).of(Time.now.to_f + 1800)])
    end
  end

  describe "a chunk GitHub rate limits" do
    let(:reset_at) { Time.now + 1800 }

    def stub_viewer_resetting(reset)
      body = { viewer: { id: GitHubGraphQL::VIEWER_ID } }
      body[:rateLimit] = { limit: 5000, remaining: 10, resetAt: github_time(reset) } if reset
      stub_github(GitHubGraphQL::VIEWER_QUERY, github_json(data: body))
    end

    before { stub_refs_answer(github_rate_limited) }

    it "queues itself again at the reset time" do
      stub_viewer_resetting(reset_at)
      walk

      expect(scheduled).to contain_exactly([[repo, clock.iso8601], be_within(1).of(reset_at.to_i)])
    end

    it "reads a rate limit GitHub reports in the answer body, and its reset time" do
      spent = { rateLimit: github_rate_limit(remaining: 0, reset: reset_at) }
      stub_refs_answer(github_errors("RATE_LIMITED", data: spent))
      walk

      expect(scheduled).to contain_exactly([[repo, clock.iso8601], be_within(1).of(reset_at.to_i)])
    end

    it "reads a rate limit GitHub reports by asking to wait" do
      stub_refs_answer({ status: 429, headers: { "Retry-After" => "60" } })
      walk

      expect(scheduled.size).to eq(1)
    end

    it "waits at least a minute when GitHub named no reset time" do
      stub_viewer_resetting(nil)
      walk

      expect(scheduled.first.last).to be_within(5).of(Time.now.to_f + described_class::SOONEST_RETRY)
    end

    it "waits at least a minute when the reset time has already passed" do
      stub_viewer_resetting(Time.now - 60)
      walk

      expect(scheduled.first.last).to be_within(5).of(Time.now.to_f + described_class::SOONEST_RETRY)
    end

    it "leaves the back edge where it was, stores nothing and records nothing", :aggregate_failures do
      walk

      expect(commit_queries.backfilled_to(repo)).to eq(edge)
      expect(stored(sha)).to be_nil
      expect(failure).to be_nil
    end
  end

  describe "a chunk GitHub answers with an error" do
    before { stub_refs_answer({ status: 502 }) }

    it "records the error and what GitHub said against this repository" do
      walk

      expect(failure).to include(reason: "github_failed", message: "GitHub answered 502 for GraphQL")
    end

    it "records a refused request that is not a rate limit as an error" do
      stub_refs_answer({ status: 403, headers: { "X-RateLimit-Remaining" => "42" } })
      walk

      expect(failure).to include(reason: "github_failed")
    end

    it "records an error GitHub reports in the answer body" do
      stub_refs_answer(github_errors("INTERNAL", "something broke"))
      walk

      expect(failure).to include(reason: "github_failed")
    end

    it "records a connection that fails" do
      stub_request(:post, GitHubGraphQL::URL).to_timeout
      walk

      expect(failure).to include(reason: "github_failed")
    end

    it "ends the walk and queues nothing, so the next finder run starts it again", :aggregate_failures do
      walk

      expect(commit_queries.backfilled_to(repo)).to be_nil
      expect(scheduled).to be_empty
    end

    it "stores nothing when a later page fails, and leaves the forward edge alone", :aggregate_failures do
      stub_refs_answer(github_refs_page(github_branch("main", commit(sha)), more: true), { status: 502 })
      walk

      expect(stored(sha)).to be_nil
      expect(commit_queries.synced_through(repo)).to be_nil
    end
  end

  describe "an answer with no viewer" do
    before do
      stub_github(GitHubGraphQL::VIEWER_QUERY,
                  { body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" } })
      stub_refs(github_branch("main", commit(sha)))
    end

    it "asks for no history rather than send an empty author" do
      walk

      expect(github_request(GitHubGraphQL::REFS_QUERY)).not_to have_been_made
    end

    it "records the failure and ends the walk", :aggregate_failures do
      walk

      expect(failure).to include(reason: "github_failed", message: "GitHub sent no viewer id")
      expect(commit_queries.backfilled_to(repo)).to be_nil
    end
  end

  describe "a chunk with nothing to walk" do
    it "asks GitHub for nothing for a repository with no walk going", :aggregate_failures do
      walk("aaronmallen/unwalked")

      expect(a_request(:post, GitHubGraphQL::URL)).not_to have_been_made
      expect(scheduled).to be_empty
    end

    it "asks GitHub for nothing with no token", :aggregate_failures do
      disconnect_github
      walk

      expect(a_request(:post, GitHubGraphQL::URL)).not_to have_been_made
      expect(scheduled).to be_empty
    end
  end
end
