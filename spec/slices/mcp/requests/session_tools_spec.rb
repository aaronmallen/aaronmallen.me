# frozen_string_literal: true

RSpec.describe "MCP session tools", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }

  def create_file(path, scope: "global", **)
    mcp_answer("create_memory_file", path:, description: "Notes", scope:, **author, **)
  end

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

    it "returns an index of the files without their facts" do
      expect([started.keys, started.fetch("files").map(&:keys).uniq])
        .to eq([%w[session_id files], [%w[id path description scope repo project_id task_id fact_count]]])
    end

    it "loads and records a repo named in mixed case or with spaces around it as its lower case name" do
      paths = start(repo: " AaronMallen/Blog ").fetch("files").map { it.fetch("path") }

      expect([paths, sessions.first.fetch("repo")]).to eq([%w[preferences.md hanami.md release.md], "aaronmallen/blog"])
    end

    it "refuses a repo that is not owner/name" do
      mcp_call("start_session", title: "Spike", **author, repo: "aaronmallen")

      expect(mcp_message).to eq("repo: name the repository as owner/name")
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

  it "names the idle time that closes a session in the tool's description" do
    mcp_rpc("tools/list")

    expect(mcp_result.fetch("tools").find { it.fetch("name") == "start_session" }.fetch("description"))
      .to include("a session no call names for 2 hours closes on its own")
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

  describe "a write into a session that ended" do
    def entry = mcp_answer("read_memory_file", id: file).fetch("history").first.fetch("id")

    let(:file) { create_file("hanami").fetch("id") }
    let!(:fact) do
      mcp_answer("add_memory_fact", id: file, type: "gotcha", text: "Mind the cache", **author).fetch("id")
    end
    let(:artifact) { mcp_answer("create_artifact", title: "Plan", type: "plan", body: "Steps", **author).fetch("id") }
    let(:session_id) { start.fetch("session_id").tap { mcp_answer("end_session", id: it) } }

    {
      "create_memory_file" => -> { { path: "other", description: "Notes", scope: "global" } },
      "describe_memory_file" => -> { { id: file, description: "When to read it" } },
      "move_memory_file" => -> { { id: file, scope: "repo", repo: "aaronmallen/blog" } },
      "add_memory_fact" => -> { { id: file, type: "gotcha", text: "Mind the queue" } },
      "edit_memory_fact" => -> { { id: file, fact_id: fact, text: "Mind the queue" } },
      "remove_memory_fact" => -> { { id: file, fact_id: fact } },
      "revert_memory_event" => -> { { id: file, event_id: entry } },
      "create_artifact" => -> { { title: "Spec", type: "plan", body: "Steps" } },
      "update_artifact" => -> { { id: artifact, body: "More steps" } },
      "restore_artifact_version" => -> { { id: artifact, version: 1 } },
    }.each do |tool, arguments|
      it "refuses #{tool}" do
        mcp_call(tool, **instance_exec(&arguments), session_id:, **author)

        expect(mcp_message).to include("that session is not open")
      end
    end
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
