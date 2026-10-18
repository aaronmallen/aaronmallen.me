# frozen_string_literal: true

RSpec.describe "API memory", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:file) { call_api(:post, "/memory_files", { path: "hanami", scope: "global", **author }).fetch("id") }
  let(:fact) do
    call_api(:post, "/memory_files/#{file}/facts", { type: "gotcha", text: "Mind the cache", **author }).fetch("id")
  end

  it "walks a file through every change and answers each as documented" do
    call_api(:patch, "/memory_files/#{file}/facts/#{fact}", { text: "Mind the query cache", **author })
    call_api(:post, "/memory_files/#{file}/facts/#{fact}/remove", author)
    removed = call_api(:get, "/memory_files/#{file}").fetch("history").first.fetch("id")
    call_api(:post, "/memory_files/#{file}/history/#{removed}/revert", author)

    expect(call_api(:get, "/memory").fetch("markdown")).to eq(<<~MARKDOWN)
      <!-- global · 1 fact -->

      # hanami

      ## Gotchas

      - Mind the query cache
    MARKDOWN
  end

  it "refuses to add a fact that names no agent" do
    call_api(:post, "/memory_files/#{file}/facts", { type: "gotcha", text: "Trust me" })

    expect([last_response.status, document.fetch("errors")])
      .to eq([422, { "agent" => ["agent is missing"], "model" => ["model is missing"] }])
  end

  it "refuses to edit a fact without naming an agent and keeps the agent's name on it" do
    call_api(:patch, "/memory_files/#{file}/facts/#{fact}", { text: "Trust me" })
    status = last_response.status

    expect([status, call_api(:get, "/memory_files/#{file}").fetch("facts").first])
      .to match([422, include("text" => "Mind the cache", "agent" => "claude-code", "model" => "claude-opus-5-5")])
  end

  it "names the agent that edits another agent's fact" do
    call_api(:patch, "/memory_files/#{file}/facts/#{fact}", { text: "Trust me", agent: "codex", model: "gpt-5" })

    expect(call_api(:get, "/memory_files/#{file}").fetch("facts").first)
      .to include("text" => "Trust me", "agent" => "codex", "model" => "gpt-5")
  end

  it "refuses to revert a change without naming an agent" do
    call_api(:post, "/memory_files/#{file}/facts/#{fact}/remove", author)
    removed = call_api(:get, "/memory_files/#{file}").fetch("history").last.fetch("id")
    call_api(:post, "/memory_files/#{file}/history/#{removed}/revert", {})

    expect([last_response.status, document.fetch("errors")])
      .to eq([422, { "agent" => ["agent is missing"], "model" => ["model is missing"] }])
  end

  it "refuses an agent without a model" do
    call_api(:post, "/memory_files/#{file}/facts", { type: "gotcha", text: "Half named", agent: "claude-code" })

    expect([last_response.status, document.fetch("errors")]).to eq([422, { "model" => ["model is missing"] }])
  end

  it "refuses a blank agent beside a model" do
    call_api(:post, "/memory_files", { path: "hanami", scope: "global", agent: "", model: "claude-opus-5-5" })

    expect(document.fetch("errors")).to eq("agent" => ["name the agent along with its model"])
  end

  it "refuses an agent over the slug limit" do
    call_api(:post, "/memory_files", { path: "hanami", scope: "global", **author, agent: "a" * 65 })

    expect(document.fetch("errors")).to eq("agent" => ["keep an agent to 64 characters"])
  end

  it "refuses a repo file without a repo" do
    call_api(:post, "/memory_files", { path: "hanami", scope: "repo", **author })

    expect(document.fetch("errors")).to eq("repo" => ["a repo file needs a repo"])
  end

  it "refuses a task file for a task that does not exist" do
    call_api(:post, "/memory_files", { path: "notes", scope: "task", task_id: 999_999, **author })

    expect([last_response.status,
            document.fetch("errors")]).to eq([422, { "task_id" => ["a task file needs a task that exists"] }])
  end

  it "refuses a revert of the file's creation" do
    created = call_api(:get, "/memory_files/#{file}").fetch("history").first.fetch("id")
    call_api(:post, "/memory_files/#{file}/history/#{created}/revert", author)

    expect(document.fetch("errors")).to eq("event_id" => ["only an add, an edit or a remove can be reverted"])
  end

  it "refuses an edit to a removed fact" do
    call_api(:post, "/memory_files/#{file}/facts/#{fact}/remove", author)
    call_api(:patch, "/memory_files/#{file}/facts/#{fact}", { text: "Back again", **author })

    expect(last_response.status).to eq(404)
  end

  it "deletes a file for a token with agents and delete" do
    call_api(:delete, "/memory_files/#{file}", nil, token: api_token(%w[agents delete]))

    expect(document).to eq("id" => file, "deleted" => true)
  end

  it "refuses to delete a file for a token with agents alone" do
    call_api(:delete, "/memory_files/#{file}", nil, token: api_token(%w[agents]))

    expect([last_response.status, document.fetch("error_description")])
      .to eq([403, "this endpoint needs a token with the delete scope"])
  end

  it "refuses memory to a token without agents" do
    call_api(:get, "/memory", nil, token: api_token(%w[read write delete]))

    expect(last_response.status).to eq(403)
  end
end
