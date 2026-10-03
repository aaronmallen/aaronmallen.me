# frozen_string_literal: true

RSpec.describe Tasks::Operations::SyncIssues do
  let(:client) { Spec::IssueClient.new }
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:url) { "https://linear.app/acme/issue/ABC-1" }

  def assign(*issues) = client.assigned.concat(issues)

  def comment = { author: "octocat", body: "Still on it", created_at: Time.now, id: "LC_1", url: "#{url}#c1" }

  def imported = repo.by_source("linear", "L_one")

  def issue(remote_state = "open", **)
    { body: "Keep them in step", id: "L_one", reference: "ABC-1", remote_state:, title: "Sync my issues", url:, ** }
  end

  def sync = Tasks::Slice["operations.sync_issues"].call(provider: "linear", client:)

  def tracked(*traits, state: "open", checked_at: nil)
    task = create(:task, *traits, list: "external", title: "Sync my issues", note: "Keep them in step")
    create(:task_source, provider: "linear", remote_id: "L_one", url:, remote_state: state, checked_at:, task:)

    repo.by_id(task.id)
  end

  describe "a new issue that has already started" do
    it "arrives with its task in progress", :aggregate_failures do
      assign(issue("started"))
      sync

      expect(imported).to have_attributes(list: nil, status: "in_progress")
      expect(imported.source.remote_state).to eq("started")
    end

    it "arrives unseen" do
      assign(issue("started"))
      sync

      expect(imported.source.seen_at).to be_nil
    end
  end

  describe "an issue that starts" do
    it "puts its task in progress", :aggregate_failures do
      task = tracked
      assign(issue("started"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(list: nil, status: "in_progress")
      expect(repo.by_id(task.id).sprint_id).not_to be_nil
    end

    it "leaves an unseen task unseen as it moves into Today" do
      task = tracked
      assign(issue("started"))
      sync

      expect(repo.by_id(task.id).source.seen_at).to be_nil
    end

    it "reopens the task when the issue goes back to open" do
      task = tracked(:in_progress, state: "started")
      assign(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "reopens a task I closed by hand when the issue goes back to open" do
      task = tracked(:done, state: "started")
      assign(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "leaves a task I closed by hand closed while the issue stays started" do
      task = tracked(:done, state: "started")
      assign(issue("started"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "a synced issue's work session" do
    let(:synced_at) { Time.at(Time.now.to_i - 600) }

    def sessions(task) = Tasks::Slice["relations.work_sessions"].for_task(task.id).to_a

    def started(task) = create(:work_session, task_id: task.id, started_at: synced_at - 3600)

    def sync_at(now) = Tasks::Slice["operations.sync_issues"].call(provider: "linear", client:, now:)

    it "opens when the issue starts, at the time of the sync" do
      task = tracked
      assign(issue("started"))
      sync_at(synced_at)

      expect(sessions(task).map { [it[:started_at], it[:ended_at]] }).to eq([[synced_at, nil]])
    end

    it "opens when a new issue arrives already started" do
      assign(issue("started"))
      sync_at(synced_at)

      expect(sessions(imported).map { it[:started_at] }).to eq([synced_at])
    end

    it "ends when the issue completes" do
      task = tracked(:in_progress, state: "started")
      started(task)
      assign(issue("completed"))
      sync_at(synced_at)

      expect(sessions(task).map { it[:ended_at] }).to eq([synced_at])
    end

    it "adds its length to the total when the issue completes" do
      task = tracked(:in_progress, state: "started")
      started(task)
      assign(issue("completed"))
      sync_at(synced_at)

      expect(repo.by_id(task.id).worked_seconds).to eq(3600)
    end

    it "ends when the issue closes as not planned" do
      task = tracked(:in_progress, state: "started")
      started(task)
      assign(issue("not_planned"))
      sync_at(synced_at)

      expect(sessions(task).map { it[:ended_at] }).to eq([synced_at])
    end

    it "ends when the issue goes back to open" do
      task = tracked(:in_progress, state: "started")
      started(task)
      assign(issue)
      sync_at(synced_at)

      expect(sessions(task).map { it[:ended_at] }).to eq([synced_at])
    end
  end

  describe "a synced issue's events" do
    let(:synced_at) { Time.at(Time.now.to_i - 600) }

    def statuses(task)
      found = Tasks::Slice["relations.task_events"].for_task(task.id).where(kind: "status_changed").in_order

      found.to_a.map { [it[:from_status], it[:to_status], it[:occurred_at]] }
    end

    def sync_at(now) = Tasks::Slice["operations.sync_issues"].call(provider: "linear", client:, now:)

    it "records a start at the time of the sync" do
      task = tracked
      assign(issue("started"))
      sync_at(synced_at)

      expect(statuses(task)).to eq([["open", "in_progress", synced_at]])
    end

    it "records a pause when the issue goes back to open" do
      task = tracked(:in_progress, state: "started")
      assign(issue)
      sync_at(synced_at)

      expect(statuses(task)).to eq([["in_progress", "open", synced_at]])
    end

    it "records a complete" do
      task = tracked(:in_progress, state: "started")
      assign(issue("completed"))
      sync_at(synced_at)

      expect(statuses(task)).to eq([["in_progress", "done", synced_at]])
    end

    it "records a cancel" do
      task = tracked
      assign(issue("not_planned"))
      sync_at(synced_at)

      expect(statuses(task)).to eq([["open", "canceled", synced_at]])
    end

    it "records a reopen" do
      task = tracked(:done, state: "completed")
      assign(issue)
      sync_at(synced_at)

      expect(statuses(task)).to eq([["done", "open", synced_at]])
    end

    it "records the tags a new issue arrives with" do
      create(:tag, :private, name: "bug-fix")
      assign(issue(labels: ["Bug Fix"]))
      sync

      expect(Tasks::Slice["relations.task_events"].for_task(imported.id).to_a.map { [it[:kind], it[:tag_name]] })
        .to eq([%w[tagged bug-fix]])
    end
  end

  describe "an issue reopened while I work on its closed task" do
    it "leaves the task in progress" do
      task = tracked(:in_progress, state: "completed")
      assign(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("in_progress")
    end
  end

  describe "a started issue whose task I moved to a list" do
    it "leaves the task open while the issue stays started" do
      task = tracked(:in_progress, state: "started")
      Tasks::Slice["operations.move_task"].call(task.id, "external")
      assign(issue("started"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(list: "external", status: "open")
    end
  end

  describe "an issue's comments" do
    def heard(task) = Tasks::Slice["queries.task_comments"].call(task.id).map(&:remote_id)

    it "reach a task its issue reopens" do
      task = tracked(:done, state: "completed")
      assign(issue(comments: [comment]))
      sync

      expect(heard(task)).to eq(%w[LC_1])
    end

    it "stop at a task its issue cancels" do
      task = tracked
      assign(issue("not_planned", comments: [comment]))
      sync

      expect(heard(task)).to be_empty
    end
  end

  describe "a deleted issue assigned to me again" do
    it "reopens its task instead of importing another" do
      task = tracked(:canceled, state: "deleted")
      assign(issue)
      sync

      expect(imported).to have_attributes(id: task.id, status: "open")
    end
  end

  describe "a run" do
    before do
      tracked
      allow(repo).to receive(:by_id).and_call_original
      replace_component("repos.task_repo", repo)
    end

    it "loads each followed task once" do
      assign(issue(comments: [comment]))
      sync

      expect(repo).to have_received(:by_id).once
    end
  end

  describe "an issue checked an hour ago" do
    %w[completed not_planned unassigned].each do |state|
      it "stays out of the run while #{state}" do
        tracked(:canceled, state:, checked_at: Time.now - 3600)
        sync

        expect(client.asked).to eq({})
      end
    end

    it "is asked about again while started" do
      tracked(:in_progress, state: "started", checked_at: Time.now - 3600)
      sync

      expect(client.asked).to eq("L_one" => url)
    end
  end

  describe "the provider it syncs" do
    it "links a new task to that provider" do
      assign(issue)
      sync

      expect(imported.source).to have_attributes(provider: "linear", remote_id: "L_one", remote_state: "open", url:)
    end

    it "leaves another provider's issues alone" do
      create(:task_source, provider: "github", remote_id: "I_seven")
      sync

      expect(client.asked).to eq({})
    end
  end

  describe "a failed run" do
    it "names the provider that failed" do
      client.failure = Record::Error.new("Linear answered 500")

      expect(sync).to eq(Dry::Monads::Failure([:linear_failed, "Linear answered 500"]))
    end

    it "reports a rate limit" do
      client.failure = Record::RateLimited.new

      expect(sync).to eq(Dry::Monads::Failure(:rate_limited))
    end

    it "reports a client with no key as not configured" do
      client.configured = false

      expect(sync).to eq(Dry::Monads::Failure(:not_configured))
    end
  end
end
