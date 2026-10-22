# frozen_string_literal: true

RSpec.describe "API sessions", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:task) { create(:task) }
  let(:session_id) do
    call_api(:post, "/agent_sessions", { title: "Spike", client: "Terminal", tasks: [task.id], **author })
      .fetch("session_id")
  end

  def loaded = call_api(:get, "/agent_sessions").fetch("sessions").first.fetch("loaded")

  def noted_file
    id = call_api(:post, "/memory_files",
                  { path: "hanami", description: "Notes", scope: "global", **author }).fetch("id")
    call_api(:post, "/memory_files/#{id}/facts", { type: "gotcha", text: "Mind the cache", **author })
    id
  end

  def walked(file)
    {
      "task_ids" => [task.id], "memory_changes" => [include("memory_file_id" => file, "op" => "create")],
      "artifact_versions" => [include("number" => 1)], "ended_at" => be_a(String),
    }
  end

  it "walks a session from start to end and answers each as documented" do
    file = call_api(:post, "/memory_files",
                    { path: "hanami", description: "Notes", scope: "global", session_id:, **author }).fetch("id")
    call_api(:post, "/artifacts", { title: "Plan", type: "plan", body: "Steps", session_id:, **author })
    call_api(:post, "/agent_sessions/#{session_id}/end")

    expect(call_api(:get, "/agent_sessions").fetch("sessions").first).to include(walked(file))
  end

  it "filters the list by the project a session ran in" do
    project = create(:project, repo: "aaronmallen/blog")
    inside = call_api(:post, "/agent_sessions", { title: "Spike", repo: "aaronmallen/blog", **author })
    call_api(:post, "/agent_sessions", { title: "Spike", **author })
    listed = call_api(:get, "/agent_sessions", { project_id: project.id }).fetch("sessions")

    expect(listed.map { it.values_at("id", "project_id") }).to eq([[inside.fetch("session_id"), project.id]])
  end

  it "records the files a session reads and searches" do
    file = noted_file
    call_api(:get, "/memory_files/#{file}", { session_id: })
    call_api(:get, "/memory/search", { query: "cache", session_id: })

    expect(loaded).to eq([{ "memory_file_id" => file, "path" => "hanami.md" }])
  end

  describe "a search in a session" do
    let!(:file) { noted_file }
    let(:query) { { query: "cache", scope: "global", repo: "aaronmallen/blog" } }

    def hits
      Agents::Slice["relations.agent_session_search_hits"].to_a.map { it.to_h.slice(:memory_file_id, :text, :path) }
    end

    it "returns the same facts as a search with no session" do
      expect(call_api(:get, "/memory/search", { **query, session_id: })).to eq(call_api(:get, "/memory/search", query))
    end

    it "records its query and filters" do
      call_api(:get, "/memory/search", { **query, session_id: })

      expect(Agents::Slice["relations.agent_session_searches"].one.to_h)
        .to include(agent_session_id: session_id, **query, project_id: nil, task_id: nil)
    end

    it "records each hit with a copy of its text and path" do
      call_api(:get, "/memory/search", { **query, session_id: })

      expect(hits).to eq([{ memory_file_id: file, text: "Mind the cache", path: "hanami.md" }])
    end
  end

  it "records a search with no hits" do
    call_api(:get, "/memory/search", { query: "nothing", session_id: })

    expect([Agents::Slice["relations.agent_session_searches"].count,
            Agents::Slice["relations.agent_session_search_hits"].count]).to eq([1, 0])
  end

  it "records no search without a session" do
    noted_file
    call_api(:get, "/memory/search", { query: "cache" })

    expect(Agents::Slice["relations.agent_session_searches"].count).to eq(0)
  end

  describe "a read in a session", :frozen_clock do
    let!(:file) { noted_file }

    def reads = Agents::Slice["relations.agent_session_reads"].to_a.map { it.to_h.slice(:memory_file_id, :read_at) }

    it "records each read with its time, repeats included" do
      2.times { call_api(:get, "/memory_files/#{file}", { session_id: }) }

      expect(reads).to eq([{ memory_file_id: file, read_at: Time.now }] * 2)
    end

    it "records no read without a session" do
      call_api(:get, "/memory_files/#{file}")

      expect(reads).to be_empty
    end

    it "records no read for a session that is not open" do
      call_api(:get, "/memory_files/#{file}", { session_id: 999 })

      expect([last_response.status, reads]).to eq([422, []])
    end
  end

  describe "an ended session" do
    let!(:file) { noted_file }

    before { call_api(:post, "/agent_sessions/#{session_id}/end") }

    def recorded
      %w[loads searches reads].sum { Agents::Slice["relations.agent_session_#{it}"].count }
    end

    it "answers a read as a read with no session does" do
      expect(call_api(:get, "/memory_files/#{file}", { session_id: })).to eq(call_api(:get, "/memory_files/#{file}"))
    end

    it "answers a search as a search with no session does" do
      expect(call_api(:get, "/memory/search", { query: "cache", session_id: }))
        .to eq(call_api(:get, "/memory/search", { query: "cache" }))
    end

    it "records no load, search or read" do
      call_api(:get, "/memory_files/#{file}", { session_id: })
      call_api(:get, "/memory/search", { query: "cache", session_id: })

      expect(recorded).to eq(0)
    end

    it "refuses a write" do
      call_api(:post, "/memory_files/#{file}/facts", { type: "gotcha", text: "Late", session_id:, **author })

      expect(document.fetch("errors")).to eq({ "session_id" => ["that session is not open; start_session opens one"] })
    end
  end

  it "records each index line it returns and returns the same index" do
    file = noted_file
    files = call_api(:post, "/agent_sessions", { title: "Spike", **author }).fetch("files")
    lines = Agents::Slice["relations.agent_session_index_lines"].to_a

    expect([files.map { it.slice("id", "path", "fact_count") }, lines.map { [it[:memory_file_id], it[:fact_count]] }])
      .to eq([[{ "id" => file, "path" => "hanami.md", "fact_count" => 1 }], [[file, 1]]])
  end

  it "refuses to end a session twice" do
    2.times { call_api(:post, "/agent_sessions/#{session_id}/end") }

    expect([last_response.status, document.fetch("errors")])
      .to eq([422, { "id" => ["session #{session_id} already ended"] }])
  end

  it "refuses a write into a session that does not exist" do
    fields = { path: "hanami", description: "Notes", scope: "global" }
    call_api(:post, "/memory_files", { **fields, session_id: 999, **author })

    expect(document.fetch("errors")).to eq({ "session_id" => ["that session is not open; start_session opens one"] })
  end

  it "refuses a session without an agent" do
    call_api(:post, "/agent_sessions", { title: "Spike" })

    expect(last_response.status).to eq(422)
  end
end
