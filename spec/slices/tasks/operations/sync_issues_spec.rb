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

  def tracked(*traits, state: "open")
    task = create(:task, *traits, list: "external", title: "Sync my issues", note: "Keep them in step")
    create(:task_source, provider: "linear", remote_id: "L_one", url:, remote_state: state, task:)

    repo.by_id(task.id)
  end

  describe "a new issue that has already started" do
    it "arrives with its task in progress", :aggregate_failures do
      assign(issue("started"))
      sync

      expect(imported).to have_attributes(list: nil, status: "in_progress")
      expect(imported.source.remote_state).to eq("started")
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
