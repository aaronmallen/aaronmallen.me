# frozen_string_literal: true

RSpec.describe "API sessions", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:task) { create(:task) }
  let(:session_id) do
    call_api(:post, "/agent_sessions", { title: "Spike", client: "Terminal", tasks: [task.id], **author })
      .fetch("session_id")
  end

  def walked(file)
    {
      "task_ids" => [task.id], "memory_changes" => [include("memory_file_id" => file, "op" => "create")],
      "artifact_versions" => [include("number" => 1)], "ended_at" => be_a(String),
    }
  end

  it "walks a session from start to end and answers each as documented" do
    file = call_api(:post, "/memory_files", { path: "hanami", scope: "global", session_id:, **author }).fetch("id")
    call_api(:post, "/artifacts", { title: "Plan", type: "plan", body: "Steps", session_id:, **author })
    call_api(:post, "/agent_sessions/#{session_id}/end")

    expect(call_api(:get, "/agent_sessions").fetch("sessions").first).to include(walked(file))
  end

  it "refuses to end a session twice" do
    2.times { call_api(:post, "/agent_sessions/#{session_id}/end") }

    expect([last_response.status, document.fetch("errors")])
      .to eq([422, { "id" => ["session #{session_id} already ended"] }])
  end

  it "refuses a write into a session that does not exist" do
    call_api(:post, "/memory_files", { path: "hanami", scope: "global", session_id: 999, **author })

    expect(document.fetch("errors")).to eq({ "session_id" => ["that session is not open; start_session opens one"] })
  end

  it "refuses a session without an agent" do
    call_api(:post, "/agent_sessions", { title: "Spike" })

    expect(last_response.status).to eq(422)
  end
end
