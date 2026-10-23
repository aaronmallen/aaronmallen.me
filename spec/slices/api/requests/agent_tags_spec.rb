# frozen_string_literal: true

RSpec.describe "API agent tags", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:project) { create(:project, key: "BLOG", repo: "aaronmallen/blog") }

  def held(table, owner_key, id)
    rows = Tags::Slice["relations.tags"].dataset.db[table].join(:tags, id: :tag_id).where(owner_key => id)
    rows.order(:name).select_map(%i[name scope project_id])
  end

  def link(id, other)
    Links::Slice["operations.link_records"].call("artifact", id, { other_kind: "project", other_id: other })
  end

  def session(**) = call_api(:post, "/agent_sessions", { title: "Spike", **author, ** }).fetch("session_id")

  describe "a session" do
    it "takes its project's own tag, made there when missing", :aggregate_failures do
      id = session(repo: project.repo)
      reply = call_api(:post, "/agent_sessions/#{id}/tags", { tag: "Perf" })

      expect([status, reply.fetch("tags")]).to eq([201, %w[perf]])
      expect(held(:agent_session_tags, :agent_session_id, id)).to eq([["perf", "project", project.id]])
    end

    it "takes a private tag when it ran in no project" do
      id = session
      call_api(:post, "/agent_sessions/#{id}/tags", { tag: "perf" })

      expect(held(:agent_session_tags, :agent_session_id, id)).to eq([["perf", "private", nil]])
    end

    it "takes a tag off" do
      id = session(repo: project.repo)
      call_api(:post, "/agent_sessions/#{id}/tags", { tag: "perf" })

      expect(call_api(:delete, "/agent_sessions/#{id}/tags/perf").fetch("tags")).to be_empty
    end

    it "refuses to take off a tag it does not carry" do
      id = session

      expect([call_api(:delete, "/agent_sessions/#{id}/tags/perf").fetch("message"), status])
        .to eq(["session #{id} has no tag perf", 404])
    end

    it "refuses a tag that is not a slug" do
      call_api(:post, "/agent_sessions/#{session}/tags", { tag: "two words" })

      expect(status).to eq(422)
    end

    it "lists its tags" do
      id = session
      call_api(:post, "/agent_sessions/#{id}/tags", { tag: "perf" })

      expect(call_api(:get, "/agent_sessions").fetch("sessions").first.fetch("tags")).to eq(%w[perf])
    end
  end

  describe "a memory file" do
    def file(**) = call_api(:post, "/memory_files", { path: "notes", description: "Notes", **author, ** }).fetch("id")

    it "takes its project's own tag when it is a project file", :aggregate_failures do
      id = file(scope: "project", project_id: project.id)
      reply = call_api(:post, "/memory_files/#{id}/tags", { tag: "perf" })

      expect(reply.fetch("tags")).to eq(%w[perf])
      expect(held(:memory_file_tags, :memory_file_id, id)).to eq([["perf", "project", project.id]])
    end

    it "takes a private tag when it is a global file" do
      id = file(scope: "global")
      call_api(:post, "/memory_files/#{id}/tags", { tag: "perf" })

      expect(held(:memory_file_tags, :memory_file_id, id)).to eq([["perf", "private", nil]])
    end

    it "takes a tag off" do
      id = file(scope: "global")
      call_api(:post, "/memory_files/#{id}/tags", { tag: "perf" })
      call_api(:delete, "/memory_files/#{id}/tags/perf")

      expect(call_api(:get, "/memory_files/#{id}").fetch("tags")).to be_empty
    end
  end

  describe "an artifact" do
    let(:id) { call_api(:post, "/artifacts", { title: "Plan", type: "plan", body: "Steps", **author }).fetch("id") }

    def retag(*tags) = call_api(:patch, "/artifacts/#{id}", { tags:, **author })

    it "takes private tags while it links to no project" do
      retag("perf")

      expect(held(:artifact_tags, :artifact_id, id)).to eq([["perf", "private", nil]])
    end

    it "takes its linked project's own tags in place of private ones" do
      retag("perf")
      link(id, project.id)
      retag("perf")

      expect(held(:artifact_tags, :artifact_id, id)).to eq([["perf", "project", project.id]])
    end

    it "takes a copy of each tag in every project it links to" do
      other = create(:project, key: "POD")
      [project, other].each { link(id, it.id) }
      retag("perf")

      expect(held(:artifact_tags, :artifact_id, id).map(&:last)).to contain_exactly(project.id, other.id)
    end

    it "drops a project's tags when its link to that project goes" do
      other = create(:project, key: "POD")
      [project, other].each { link(id, it.id) }
      retag("perf")
      Links::Slice["operations.unlink_records"].call("artifact", id, "project", project.id).value!

      expect(held(:artifact_tags, :artifact_id, id).map(&:last)).to eq([other.id])
    end
  end

  describe "the project tag" do
    before do
      session_id = session(repo: project.repo)
      call_api(:post, "/agent_sessions/#{session_id}/tags", { tag: "perf" })
      fields = { path: "notes", description: "Notes", scope: "project", project_id: project.id, **author }
      file_id = call_api(:post, "/memory_files", fields).fetch("id")
      call_api(:post, "/memory_files/#{file_id}/tags", { tag: "perf" })
      artifact_id = call_api(:post, "/artifacts", { title: "Plan", type: "plan", body: "Steps", **author }).fetch("id")
      link(artifact_id, project.id)
      call_api(:patch, "/artifacts/#{artifact_id}", { tags: ["perf"], **author })
    end

    def read(token) = call_api(:get, "/tags/perf", { project: "BLOG" }, token:)

    it "lists each agent record that carries it" do
      answer = read(api_token)

      expect(%w[agent_sessions memory_files artifacts].map { answer.fetch(it).fetch("records").size }).to eq([1, 1, 1])
    end

    it "leaves the agent records out for a token without agents", :aggregate_failures do
      answer = read(api_token(%w[read]))

      expect(answer.keys).not_to include("agent_sessions", "memory_files", "artifacts")
      expect(answer.fetch("counts").keys).not_to include("agent_sessions", "memory_files", "artifacts")
    end
  end
end
