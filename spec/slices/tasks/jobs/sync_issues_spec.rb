# frozen_string_literal: true

require "fugit"

RSpec.describe Tasks::Jobs::SyncIssues do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }
  let(:url) { "https://github.com/aaronmallen/aaronmallen.me/issues/7" }

  before do
    connect_github_token
    stub_assigned
    stub_known
  end

  def api = "https://api.github.com"

  def comments(task = imported) = Tasks::Slice["queries.task_comments"].call(task.id)

  def discussed(*nodes, **) = issue(comments: { nodes: }, **)

  def failure = sync_state_repo.failure(Record::Repos::SyncStateRepo::ISSUES)

  def imported(id = "I_seven") = repo.by_source("github", id)

  def issue(id = "I_seven", **) = github_issue(id, number: 7, **)

  def stub_assigned(*nodes) = stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(*nodes))

  def stub_known(*nodes)
    stub_github(GitHubGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      github_issue_nodes(*ids.map { |id| nodes.find { it[:id] == id } })
    end
  end

  def stub_rest(path, response) = stub_request(:get, "#{api}/repos/#{path}").to_return(response)

  def stub_vanished(response)
    stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)
    stub_rest("aaronmallen/aaronmallen.me/issues/7", response)
  end

  def sync = described_class.new.perform

  def tracked(*traits, state: "open", checked_at: nil, **)
    task = create(:task, *traits, list: "external", **)

    create(:task_source, remote_id: "I_seven", url:, remote_state: state, checked_at:, task:)
      .then { repo.by_id(it.task_id) }
  end

  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync my issues", body: "Keep them in step")) }

    it "becomes a task on the external list with no tags", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: "external", note: "Keep them in step", sprint_id: nil,
                                          status: "open", title: "Sync my issues")
      expect(imported.tags).to be_empty
    end

    it "links the task to its issue" do
      sync

      expect(imported.source).to have_attributes(provider: "github", remote_id: "I_seven", url:)
    end

    it "arrives unseen" do
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "makes one task when the job runs twice" do
      2.times { sync }

      expect(Tasks::Slice["relations.task_sources"].where(remote_id: "I_seven").count).to eq(1)
    end

    it "clears a failure the last run left" do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::ISSUES, :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "a new issue with labels" do
    before { create(:tag, :private, name: "bug-fix") }

    def labeled(*names) = issue(labels: { nodes: names.map { { name: it } } })

    it "imports with the private tags its labels name" do
      create(:tag, :private, name: "needs-review")
      stub_assigned(labeled("Bug Fix", "needs review", "BugFix"))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("bug-fix", "needs-review")
    end

    it "arrives unseen with its tags" do
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "adds no tag and creates none for a label no private tag matches", :aggregate_failures do
      create(:tag, name: "area-api")
      stub_assigned(labeled("area/api", "Someday"))

      expect { sync }.not_to(change { Tags::Slice["relations.tags"].count })
      expect(imported.tags).to be_empty
    end

    it "keeps a tag I removed off on the next sync" do
      stub_assigned(labeled("Bug Fix"))
      sync
      repo.replace_tags(imported.id, [])
      sync

      expect(imported.tags).to be_empty
    end

    it "adds no tag for a label added after import" do
      stub_assigned(labeled)
      sync
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(imported.tags).to be_empty
    end
  end

  describe "a new issue from a repo with tag rules" do
    before do
      create(:tag, :private, name: "bug-fix")
      rule("aaronmallen/aaronmallen.me", "ruby, hanami")
      rule("aaronmallen/*", "projects, ruby")
    end

    def events = Tasks::Slice["relations.task_events"].for_task(imported.id).to_a

    def rule(pattern, tags) = Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, tags: })

    it "imports with the tags of every rule it matches beside its label tags" do
      stub_assigned(issue(labels: { nodes: [{ name: "Bug Fix" }] }))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("bug-fix", "hanami", "projects", "ruby")
    end

    it "records each tag once in the import's task event" do
      stub_assigned(issue(labels: { nodes: [{ name: "Ruby" }] }))
      sync

      expect(events.map { [it[:kind], it[:tag_name]] })
        .to contain_exactly(%w[tagged hanami], %w[tagged projects], %w[tagged ruby])
    end

    it "matches the repo whatever its case" do
      stub_assigned(issue(repo: "AaronMallen/AaronMallen.me"))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("hanami", "projects", "ruby")
    end

    it "takes no rule tags when the issue comes from another owner" do
      stub_assigned(issue(repo: "octocat/aaronmallen.me"))
      sync

      expect(imported.tags).to be_empty
    end

    it "keeps a tag I removed off on the next sync" do
      stub_assigned(issue)
      sync
      repo.replace_tags(imported.id, %w[ruby])
      sync

      expect(imported.tags.map(&:name)).to eq(%w[ruby])
    end
  end

  describe "an issue edited on GitHub" do
    it "takes the new title and body" do
      task = tracked(title: "Old", note: "Old body")
      stub_assigned(issue(title: "New", body: "New body"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(note: "New body", title: "New")
    end

    it "leaves an unchanged task untouched" do
      task = tracked(title: "Sync my issues", note: "Keep them in step", updated_at: Time.now - 3600)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).updated_at).to be_within(1).of(task.updated_at)
    end

    it "follows the issue to its new URL" do
      task = tracked
      stub_assigned(issue(repo: "aaronmallen/renamed"))
      sync

      expect(repo.by_id(task.id).source.url).to eq("https://github.com/aaronmallen/renamed/issues/7")
    end
  end

  describe "an issue with a NUL byte in its title or body" do
    it "imports as a task without the byte" do
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync

      expect(imported).to have_attributes(note: "Keep them in step", title: "Sync my issues")
    end

    it "takes a later change as usual" do
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync
      stub_assigned(issue(title: "Sync\u0000 every issue", body: "Keep\u0000 them all in step"))
      sync

      expect(imported).to have_attributes(note: "Keep them all in step", title: "Sync every issue")
    end

    it "leaves the task untouched while the issue stays the same" do
      task = tracked(title: "Sync my issues", note: "Keep them in step", updated_at: Time.now - 3600)
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync

      expect(repo.by_id(task.id).updated_at).to be_within(1).of(task.updated_at)
    end
  end

  describe "an issue whose title is blank once cleaned" do
    let(:reference) { "aaronmallen/aaronmallen.me#7" }

    it "imports with its reference as the title" do
      stub_assigned(issue(title: "\u0000 \u0000"))
      sync

      expect(imported.title).to eq(reference)
    end

    it "keeps that title while the issue's title stays blank" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: " \u0000 ", body: "New body"))
      sync

      expect(imported).to have_attributes(note: "New body", title: reference)
    end

    it "takes a real title once the issue has one" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: "Sync my issues"))
      sync

      expect(imported.title).to eq("Sync my issues")
    end
  end

  describe "an issue's comments" do
    let(:at) { Time.utc(2026, 9, 28, 12) }

    def copied(id, author:, at:)
      { author:, body: "Looks good", created_at: at, provider: "github", remote_id: id,
        url: "https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-#{id.delete_prefix('IC_')}" }
    end

    def remote(comment) = comment.to_h.slice(:author, :body, :created_at, :provider, :remote_id, :url)

    def sync_twice(first, second)
      stub_assigned(first)
      sync
      stub_assigned(second)
      sync
    end

    it "arrive on its task with author, body, time and link" do
      stub_assigned(discussed(github_comment("IC_1", at:), github_comment("IC_2", author: "hubot", at: at + 60)))
      sync

      expect(comments.map { remote(it) })
        .to eq([copied("IC_1", author: "octocat", at:), copied("IC_2", author: "hubot", at: at + 60)])
    end

    it "arrive on a task already tracked" do
      task = tracked
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task).map(&:remote_id)).to eq(%w[IC_1])
    end

    it "add no rows and change nothing when synced again unchanged", :aggregate_failures do
      stub_assigned(discussed(github_comment("IC_1"), github_comment("IC_2")))
      before = sync.then { comments.map(&:to_h) }
      sync

      expect(comments.map(&:to_h)).to eq(before)
      expect(Tasks::Slice["relations.task_comments"].count).to eq(2)
    end

    it "take an edit made on GitHub" do
      sync_twice(discussed(github_comment("IC_1")), discussed(github_comment("IC_1", body: "Edited")))

      expect(comments.map(&:body)).to eq(%w[Edited])
    end

    it "lose one deleted on GitHub" do
      sync_twice(discussed(github_comment("IC_1"), github_comment("IC_2")), discussed(github_comment("IC_2")))

      expect(comments.map(&:remote_id)).to eq(%w[IC_2])
    end

    it "leave my own comments alone" do
      task = tracked
      mine = create(:task_comment, task_id: task.id)
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task).map(&:id)).to include(mine.id)
    end

    it "skip a comment with nothing to show once cleaned" do
      stub_assigned(discussed(github_comment("IC_1", body: "\u0000 "), github_comment("IC_2", body: "Fine\u0000")))
      sync

      expect(comments.map { [it.remote_id, it.body] }).to eq([%w[IC_2 Fine]])
    end

    it "stop coming to a task I finished" do
      task = tracked(:done)
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task)).to be_empty
    end

    it "stop coming to a canceled task" do
      task = tracked(:canceled, state: "not_planned")
      stub_known(discussed(github_comment("IC_1"), state: "CLOSED", stateReason: "NOT_PLANNED"))
      sync

      expect(comments(task)).to be_empty
    end

    it "stop coming once the issue is taken off me and its task canceled" do
      task = tracked
      stub_known(discussed(github_comment("IC_1"), assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(comments(task)).to be_empty
    end

    context "when GitHub rate limits the run part way" do
      before { stub_github(GitHubGraphQL::ISSUES_QUERY, github_rate_limited) }

      it "save nothing", :aggregate_failures do
        tracked
        stub_assigned(github_issue("I_eight", number: 8, comments: { nodes: [github_comment("IC_1")] }))
        sync

        expect(failure).to include(reason: "rate_limited")
        expect(Tasks::Slice["relations.task_comments"].count).to eq(0)
      end
    end
  end

  describe "an issue closed on GitHub" do
    it "marks the task done when it closed as completed" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "cancels the task when it closed as not planned" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "NOT_PLANNED"))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "cancels the task when it closed as a duplicate" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "DUPLICATE"))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "moves the task to done when a not planned issue is closed again as completed" do
      task = tracked(:canceled, state: "not_planned")
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "an issue reopened on GitHub" do
    it "reopens its done task" do
      task = tracked(:done, state: "completed")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id)).to have_attributes(completed_at: nil, status: "open")
    end

    it "reopens its canceled task" do
      task = tracked(:canceled, state: "not_planned")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end
  end

  describe "a closed issue" do
    let(:day) { 24 * 60 * 60 }

    def checks = github_request(GitHubGraphQL::ISSUES_QUERY)

    it "is checked once, then left alone for a day" do
      tracked(:done, state: "completed")
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      2.times { sync }

      expect(checks).to have_been_made.once
    end

    it "is checked again once a day has passed", :aggregate_failures do
      task = tracked(:done, state: "completed", checked_at: Time.now - day - 60)
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(checks).to have_been_made.once
      expect(repo.by_id(task.id).source.checked_at).to be_within(5).of(Time.now)
    end

    it "moves its task back when reopened upstream" do
      task = tracked(:done, state: "completed", checked_at: Time.now - day)
      stub_known(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "is checked every run while open" do
      tracked
      stub_known(issue)
      2.times { sync }

      expect(checks).to have_been_made.twice
    end
  end

  describe "an issue taken off me" do
    it "cancels its task" do
      task = tracked
      stub_known(issue(assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "leaves a task I finished done" do
      task = tracked(:done)
      stub_known(issue(assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "reopens the task when the issue is assigned back to me" do
      task = tracked(:canceled, state: "unassigned")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end
  end

  describe "a task I closed by hand while its issue stays open" do
    it "stays closed" do
      task = tracked(:done)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "an in progress task whose issue stays open" do
    it "stays in progress" do
      task = tracked(:in_progress)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("in_progress")
    end
  end

  describe "a deleted issue" do
    before { stub_vanished({ status: 410 }) }

    it "cancels its task" do
      task = tracked
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "stops asking GitHub about it once canceled", :aggregate_failures do
      tracked
      2.times { sync }

      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).to have_been_made.once
      expect(a_request(:get, "#{api}/repos/aaronmallen/aaronmallen.me/issues/7")).to have_been_made.once
    end
  end

  describe "a gone issue assigned to me again" do
    def linked = Tasks::Slice["relations.task_sources"].where(remote_id: "I_seven").pluck(:task_id)

    %w[deleted moved].each do |state|
      it "reopens the task it had when it was #{state}", :aggregate_failures do
        task = tracked(:canceled, state:)
        stub_assigned(issue)
        sync

        expect(linked).to eq([task.id])
        expect(repo.by_id(task.id)).to have_attributes(status: "open", source: have_attributes(remote_state: "open"))
      end
    end

    it "lets the rest of the run import" do
      tracked(:canceled, state: "deleted")
      stub_assigned(issue, github_issue("I_eight", number: 8))
      sync

      expect(imported("I_eight").status).to eq("open")
    end

    it "lets the run clear a failure the last run left" do
      tracked(:canceled, state: "deleted")
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::ISSUES, :rate_limited)
      stub_assigned(issue)
      sync

      expect(failure).to be_nil
    end

    it "is not asked about while it stays gone" do
      tracked(:canceled, state: "deleted")
      sync

      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).not_to have_been_made
    end
  end

  describe "an issue moved to another repository" do
    let(:moved_url) { "https://github.com/aaronmallen/elsewhere/issues/3" }

    before do
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)
      stub_rest("aaronmallen/aaronmallen.me/issues/7",
                { status: 301, headers: { "Location" => "#{api}/repos/aaronmallen/elsewhere/issues/3" } })
      stub_rest("aaronmallen/elsewhere/issues/3", github_json(html_url: moved_url))
    end

    it "cancels the old task" do
      task = tracked
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "imports the moved issue as a new task when it is still mine", :aggregate_failures do
      tracked
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3))
      sync

      expect(imported("I_three")).to have_attributes(list: "external", status: "open")
      expect(imported("I_three").source.url).to eq(moved_url)
    end

    it "makes one new task when the job runs twice" do
      tracked
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3))
      2.times { sync }

      expect(Tasks::Slice["relations.task_sources"].count).to eq(2)
    end

    it "moves the issue's comments to the new task" do
      create(:task_comment, :synced, task_id: tracked(:canceled, state: "moved").id, remote_id: "IC_1")
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3,
                                            comments: { nodes: [github_comment("IC_1")] }))
      sync

      expect(comments(imported("I_three")).map(&:remote_id)).to eq(%w[IC_1])
    end

    it "imports nothing when the moved issue is no longer mine" do
      tracked
      sync

      expect(Tasks::Slice["relations.task_sources"].count).to eq(1)
    end
  end

  describe "a failed run" do
    it "records GitHub's refusal under issues", :aggregate_failures do
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_rate_limited)
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(repo.by_source("github", "I_seven")).to be_nil
    end

    it "records a check GitHub fails rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_vanished({ status: 500 })
      sync

      expect(failure).to include(reason: "github_failed")
      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "catches up on the next run from what it stored", :aggregate_failures do
      task = tracked
      stub_github(GitHubGraphQL::ISSUES_QUERY, { status: 500 }, github_issue_nodes(issue(state: "CLOSED")))
      2.times { sync }

      expect(failure).to be_nil
      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "with no GitHub token" do
    before { disconnect_github }

    it "asks GitHub for nothing and records nothing", :aggregate_failures do
      sync

      expect(a_request(:any, %r{\A#{api}/})).not_to have_been_made
      expect(failure).to be_nil
    end
  end

  describe "when another run is already going" do
    let(:connection) { Tasks::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }

    before { elsewhere.get(Sequel.function(:pg_try_advisory_lock, Tasks::Repos::TaskSourceRepo::SYNC_LOCK)) }

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock", :aggregate_failures do
      sync

      expect(github_request(GitHubGraphQL::ASSIGNED_QUERY)).not_to have_been_made
      expect(failure).to be_nil
    end
  end

  describe "a sync asked for now" do
    let(:queue) { Tasks::Slice["operations.queue_issue_sync"] }

    it "queues the job" do
      queue.call

      expect(described_class.jobs.size).to eq(1)
    end

    it "queues nothing without a token", :aggregate_failures do
      disconnect_github

      expect(queue.call).to eq(Dry::Monads::Failure(:not_configured))
      expect(described_class.jobs).to be_empty
    end
  end

  describe "the schedule" do
    let(:entry) { sidekiq_schedule("sync_issues") }

    it "names the job" do
      expect(Object.const_get(entry.fetch("class"))).to eq(described_class)
    end

    it "runs the job every 15 minutes" do
      cron = Fugit::Cron.parse(entry.fetch("cron"))
      first = cron.next_time(Time.utc(2026, 9, 17, 12, 1))

      expect(cron.next_time(first).to_t - first.to_t).to eq(15 * 60)
    end
  end
end
