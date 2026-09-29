# frozen_string_literal: true

require "fugit"

RSpec.describe Tasks::Jobs::SyncLinearIssues do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }
  let(:url) { "https://linear.app/aaronmallen/issue/abc-1/sync-my-issues" }

  before do
    connect_linear(LinearGraphQL::KEY)
    stub_assigned
    stub_known
  end

  def failure(name = Record::Repos::SyncStateRepo::LINEAR_ISSUES) = sync_state_repo.failure(name)

  def imported = repo.by_source("linear", "L_one")

  def issue(**) = linear_issue("L_one", **)

  def sources = Tasks::Slice["relations.task_sources"]

  def status(task) = repo.by_id(task.id).status

  def stub_assigned(*nodes) = stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(*nodes))

  def stub_known(*nodes)
    stub_linear(LinearGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      linear_issues(*nodes.select { ids.include?(it[:id]) })
    end
  end

  def sync = described_class.new.perform

  def tracked(*traits, state: "open", **)
    task = create(:task, *traits, list: "external", title: "Sync my issues", note: "Keep them in step", **)
    create(:task_source, provider: "linear", remote_id: "L_one", url:, remote_state: state, task:)

    repo.by_id(task.id)
  end

  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync Linear", description: "Keep Linear in step")) }

    it "becomes a task on the external list with no tags", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: "external", note: "Keep Linear in step", sprint_id: nil,
                                          status: "open", title: "Sync Linear")
      expect(imported.tags).to be_empty
    end

    it "links the task to its issue" do
      sync

      expect(imported.source).to have_attributes(provider: "linear", remote_id: "L_one", url:)
    end

    it "makes one task when the job runs twice" do
      2.times { sync }

      expect(sources.where(remote_id: "L_one").count).to eq(1)
    end

    it "clears a failure the last run left" do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::LINEAR_ISSUES, :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "a new issue already started" do
    before { stub_assigned(issue(state: "started")) }

    it "arrives in progress", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: nil, status: "in_progress")
      expect(imported.source.remote_state).to eq("started")
    end

    it "stays one task in progress when the job runs twice", :aggregate_failures do
      2.times { sync }

      expect(sources.where(remote_id: "L_one").count).to eq(1)
      expect(imported.status).to eq("in_progress")
    end
  end

  describe "issues in every workspace I hold a key for" do
    before do
      connect_linear(LinearGraphQL::KEY, "lin_api_two")
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(issue), key: LinearGraphQL::KEY)
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(linear_issue("L_two", key: "XYZ-2")),
                  key: "lin_api_two")
    end

    it "become one task each" do
      sync

      expect(sources.where(provider: "linear").pluck(:remote_id)).to contain_exactly("L_one", "L_two")
    end
  end

  describe "an issue edited on Linear" do
    it "takes the new title and description" do
      task = tracked
      stub_assigned(issue(title: "New", description: "New body"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(note: "New body", title: "New")
    end
  end

  describe "an issue that moves between states" do
    it "puts its task in progress when it starts" do
      task = tracked
      stub_assigned(issue(state: "started"))
      sync

      expect(status(task)).to eq("in_progress")
    end

    %w[triage backlog unstarted].each do |type|
      it "reopens its task when it moves back to #{type}" do
        task = tracked(:in_progress, state: "started")
        stub_assigned(issue(state: type))
        sync

        expect(status(task)).to eq("open")
      end
    end

    it "marks its task done when it completes" do
      task = tracked
      stub_known(issue(state: "completed"))
      sync

      expect(status(task)).to eq("done")
    end

    it "cancels its task when it is canceled" do
      task = tracked
      stub_known(issue(state: "canceled"))
      sync

      expect(status(task)).to eq("canceled")
    end
  end

  describe "an issue taken off me" do
    it "cancels its task" do
      task = tracked
      stub_known(issue(assignee: "someone-else"))
      sync

      expect(status(task)).to eq("canceled")
    end

    it "reopens the task when the issue is assigned back to me" do
      task = tracked(:canceled, state: "unassigned")
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("open")
    end
  end

  describe "a deleted issue" do
    it "cancels its task when Linear puts it in the trash" do
      task = tracked
      stub_known(issue(trashed: true))
      sync

      expect(status(task)).to eq("canceled")
    end

    it "cancels its task when Linear no longer knows it" do
      task = tracked
      sync

      expect(status(task)).to eq("canceled")
    end
  end

  describe "an archived issue" do
    it "leaves its task as it was" do
      task = tracked(:done, state: "completed")
      stub_known(issue(state: "completed", archivedAt: "2026-09-20T12:00:00.000Z"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(completed_at: task.completed_at, status: "done")
    end
  end

  describe "an issue moved to another team" do
    it "keeps the same task and follows the new link", :aggregate_failures do
      task = tracked
      stub_assigned(issue(key: "XYZ-9"))
      sync

      expect(repo.by_id(task.id).source.url).to eq("https://linear.app/aaronmallen/issue/xyz-9/sync-my-issues")
      expect(sources.count).to eq(1)
    end
  end

  describe "a status I set by hand" do
    it "holds while the issue stays in its state" do
      task = tracked(:done)
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("done")
    end

    it "gives way when the issue's state changes" do
      task = tracked(:done)
      stub_assigned(issue(state: "started"))
      sync

      expect(status(task)).to eq("in_progress")
    end
  end

  describe "a failed run" do
    it "records Linear's refusal under linear_issues", :aggregate_failures do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_errors("RATELIMITED"))
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(failure(Record::Repos::SyncStateRepo::ISSUES)).to be_nil
    end

    it "records a check Linear fails rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_linear(LinearGraphQL::ISSUES_QUERY, { status: 500 })
      sync

      expect(failure).to include(reason: "linear_failed")
      expect(status(task)).to eq("open")
    end
  end

  describe "a failure in one provider" do
    before do
      connect_github_token
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(github_issue("I_seven", number: 7)))
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(issue))
    end

    def both
      sync
      Tasks::Jobs::SyncIssues.new.perform
    end

    it "leaves GitHub to run when Linear fails", :aggregate_failures do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, { status: 500 })
      both

      expect(failure).to include(reason: "linear_failed")
      expect(repo.by_source("github", "I_seven")).not_to be_nil
    end

    it "leaves Linear to run when GitHub fails", :aggregate_failures do
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, { status: 500 })
      both

      expect(failure(Record::Repos::SyncStateRepo::ISSUES)).to include(reason: "github_failed")
      expect([failure, imported]).to match([nil, be_truthy])
    end
  end

  describe "with no Linear keys" do
    before { connect_linear }

    it "asks Linear for nothing and records nothing", :aggregate_failures do
      sync

      expect(a_request(:any, LinearGraphQL::URL)).not_to have_been_made
      expect(failure).to be_nil
    end
  end

  describe "when another run is already going" do
    let(:connection) { Tasks::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }

    before do
      lock = Tasks::Repos::TaskSourceRepo::SYNC_LOCKS.fetch("linear")
      elsewhere.get(Sequel.function(:pg_try_advisory_lock, lock))
    end

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock", :aggregate_failures do
      sync

      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY)).not_to have_been_made
      expect(failure).to be_nil
    end

    it "leaves the GitHub run free" do
      connect_github_token
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search)
      Tasks::Jobs::SyncIssues.new.perform

      expect(github_request(GitHubGraphQL::ASSIGNED_QUERY)).to have_been_made
    end
  end

  describe "a sync asked for now" do
    let(:queue) { Tasks::Slice["operations.queue_issue_sync"] }

    it "queues the Linear and GitHub jobs", :aggregate_failures do
      connect_github_token
      queue.call

      expect([described_class.jobs.size, Tasks::Jobs::SyncIssues.jobs.size]).to eq([1, 1])
    end

    it "queues the Linear job alone without a GitHub token", :aggregate_failures do
      disconnect_github
      queue.call

      expect([described_class.jobs.size, Tasks::Jobs::SyncIssues.jobs.size]).to eq([1, 0])
    end

    it "queues the GitHub job alone without a Linear key", :aggregate_failures do
      connect_linear
      connect_github_token
      queue.call

      expect([described_class.jobs.size, Tasks::Jobs::SyncIssues.jobs.size]).to eq([0, 1])
    end

    it "queues nothing when no provider is set up", :aggregate_failures do
      connect_linear
      disconnect_github

      expect(queue.call).to eq(Dry::Monads::Failure(:not_configured))
      expect(Sidekiq::Job.jobs).to be_empty
    end
  end

  describe "the schedule" do
    let(:entry) { sidekiq_schedule("sync_linear_issues") }

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
