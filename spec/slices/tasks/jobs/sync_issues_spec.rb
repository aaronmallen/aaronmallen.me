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

  def tracked(*traits, state: "open", **)
    task = create(:task, *traits, list: "external", **)

    create(:task_source, remote_id: "I_seven", url:, remote_state: state, task:)
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

    it "records a missing token as not configured" do
      disconnect_github
      sync

      expect(failure).to include(reason: "not_configured")
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
