# frozen_string_literal: true

RSpec.describe "MCP session tools", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }

  def create_file(path, scope: "global", **) = mcp_answer("create_memory_file", path:, scope:, **author, **)

  def mcp_scopes = %w[read agents]

  def sessions = trusted(mcp_answer("list_sessions").fetch("sessions"))

  def start(**) = mcp_answer("start_session", title: "Index the activities table", **author, **)

  describe "start_session" do
    let(:project) { create(:project, repo: "aaronmallen/blog") }
    let(:task) { create(:task) }
    let(:started) { start(repo: "aaronmallen/blog", branch: "activities-index", tasks: [task.id]) }

    before do
      create_file("task-notes", scope: "task", task_id: task.id)
      create_file("release", scope: "project", project_id: project.id)
      create_file("hanami", scope: "repo", repo: "aaronmallen/blog")
      create_file("preferences")
      create_file("elsewhere", scope: "repo", repo: "aaronmallen/other")
    end

    it "returns the global, repo, project and task files that match" do
      paths = started.fetch("files").map { it.fetch("path") }

      expect(paths).to eq(%w[preferences.md hanami.md release.md task-notes.md])
    end

    it "returns the memory as markdown" do
      expect(started.fetch("markdown")).to start_with("<!-- global · 0 facts -->\n\n# preferences\n")
    end

    it "lists the session with its tasks and the files it loaded" do
      id = started.fetch("session_id")
      loaded = %w[hanami.md preferences.md release.md task-notes.md].map { include("path" => it) }

      expect(sessions.first)
        .to include("id" => id, "branch" => "activities-index", "task_ids" => [task.id], "loaded" => loaded)
    end
  end

  it "marks the title, client and branch untrusted" do
    start(client: "Claude Code 2.4", branch: "main")

    expect(mcp_answer("list_sessions").fetch("sessions").first.values_at("title", "client", "branch"))
      .to eq([marked("Index the activities table"), marked("Claude Code 2.4"), marked("main")])
  end

  it "refuses a task that does not exist" do
    mcp_call("start_session", title: "Spike", **author, tasks: [Blog::Constants::INTEGER_MAX])

    expect(mcp_message).to include("name tasks that exist")
  end

  describe "writes that name a session" do
    let(:session_id) { start.fetch("session_id") }
    let(:file) { create_file("hanami").fetch("id") }

    before do
      mcp_answer("add_memory_fact", id: file, type: "gotcha", text: "Mind the cache", session_id:, **author)
      mcp_answer("create_artifact", title: "Plan", type: "plan", body: "Steps", session_id:, **author)
    end

    it "shows the memory change and the artifact version on the session" do
      expect(sessions.first.values_at("memory_changes", "artifact_versions")).to match(
        [[include("memory_file_id" => file, "op" => "add")], [include("number" => 1)]],
      )
    end

    it "names the session on the history entry and the version" do
      entry = mcp_answer("read_memory_file", id: file).fetch("history").first
      version = mcp_answer("read_artifact", id: sessions.first.dig("artifact_versions", 0, "artifact_id"))

      expect([entry, version.fetch("versions").last].map { it.fetch("session_id") }).to eq([session_id, session_id])
    end

    it "leaves a write without one out of every session" do
      create_file("other")

      expect(sessions.first.fetch("memory_changes").length).to eq(1)
    end
  end

  it "moves a session's last-seen time when a write names it" do
    session_id = start.fetch("session_id")
    allow(Time).to receive(:now).and_return(Time.now + 600)
    create_file("hanami", session_id:)

    expect(Time.iso8601(sessions.first.fetch("last_seen_at"))).to be_within(5).of(Time.now)
  end

  it "refuses a write into a session that ended" do
    session_id = start.fetch("session_id")
    mcp_answer("end_session", id: session_id)
    mcp_call("create_memory_file", path: "hanami", scope: "global", session_id:, **author)

    expect(mcp_message).to include("that session is not open")
  end

  describe "end_session" do
    let(:session_id) { start.fetch("session_id") }

    it "sets the end time" do
      expect(Time.iso8601(mcp_answer("end_session", id: session_id).fetch("ended_at"))).to be_within(5).of(Time.now)
    end

    it "refuses a second call" do
      mcp_answer("end_session", id: session_id)
      mcp_call("end_session", id: session_id)

      expect([mcp_refused?, mcp_message]).to match([true, include("session #{session_id} already ended")])
    end
  end
end
