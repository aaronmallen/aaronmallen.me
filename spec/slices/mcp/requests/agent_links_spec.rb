# frozen_string_literal: true

RSpec.describe "MCP agent record links", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:task) { create(:task, title: "Index the activities table") }

  def create_artifact(title = "Index plan")
    mcp_answer("create_artifact", title:, type: "plan", body: "## Steps", **author)
  end

  def create_file(path = "hanami", scope: "global", **) = mcp_answer("create_memory_file", path:, scope:, **author, **)

  def link(kind, id, other_kind, other_id) = mcp_answer("link_records", kind:, id:, other_kind:, other_id:)

  def links(kind, id) = mcp_answer("list_links", kind:, id:).fetch("links")

  def mcp_scopes = %w[read write agents delete]

  describe "a connection with agents" do
    it "links a memory file and an artifact to a task, marking their titles untrusted" do
      file, artifact = [create_file, create_artifact].map { it.fetch("id") }
      link("memory_file", file, "task", task.id)
      link("task", task.id, "artifact", artifact)

      expect(links("task", task.id).transform_values { it.map { it.fetch("title") } })
        .to eq("memory_file" => [marked("hanami.md")], "artifact" => [marked("Index plan")])
    end

    it "shows the links in read_task" do
      artifact = create_artifact.fetch("id")
      link("artifact", artifact, "task", task.id)

      expect(mcp_answer("read_task", id: task.id).dig("record_links", "artifact").map { it.fetch("id") })
        .to eq([artifact])
    end

    it "links an artifact to another artifact and to a commit" do
      artifact, other = [create_artifact, create_artifact("Handoff")].map { it.fetch("id") }
      commit = create(:commit).id
      { "artifact" => other, "commit" => commit }.each { link("artifact", artifact, *it) }

      expect(links("artifact", artifact).transform_values { it.map { it.fetch("id") } })
        .to eq("commit" => [commit], "artifact" => [other])
    end

    it "removes the links of a deleted memory file or artifact" do
      file, artifact = [create_file, create_artifact].map { it.fetch("id") }
      link("memory_file", file, "task", task.id)
      link("artifact", artifact, "task", task.id)
      { "delete_memory_file" => file, "delete_artifact" => artifact }.each { |name, id| mcp_call(name, id:) }

      expect([links("task", task.id), Links::Slice["relations.record_links"].count]).to eq([{}, 0])
    end
  end

  describe "a file scoped to a task" do
    let!(:file) { create_file(scope: "task", task_id: task.id).fetch("id") }

    it "shows a link to its task from both sides" do
      expect([links("task", task.id).dig("memory_file", 0, "id"), links("memory_file", file).dig("task", 0, "id")])
        .to eq([file, task.id])
    end

    it "refuses to unlink it, saying to change the scope" do
      text = mcp_text("unlink_records", kind: "task", id: task.id, other_kind: "memory_file", other_id: file)

      expect([text, links("task", task.id).keys])
        .to eq(["other_id: this memory file is scoped to that record, so change its scope instead", %w[memory_file]])
    end

    it "refuses a second link to its task" do
      text = mcp_text("link_records", kind: "memory_file", id: file, other_kind: "task", other_id: task.id)

      expect([text, Links::Slice["relations.record_links"].count])
        .to eq(["other_id: these two records are already linked", 0])
    end

    it "shows a link to its project" do
      project = create(:project)
      scoped = create_file("rails", scope: "project", project_id: project.id).fetch("id")

      expect(links("project", project.id).dig("memory_file", 0, "id")).to eq(scoped)
    end
  end

  describe "a connection without agents" do
    def mcp_scopes = %w[read write delete]

    let(:artifact) { create(:artifact) }

    it "refuses to link a record to an artifact, naming agents" do
      text = mcp_text("link_records", kind: "task", id: task.id, other_kind: "artifact", other_id: artifact.id)

      expect([text, Links::Slice["relations.record_links"].count])
        .to eq(["this endpoint needs a token with the agents scope", 0])
    end

    it "hides a linked memory file or artifact from list_links and read_task" do
      Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "artifact", other_id: artifact.id })
      create(:memory_file, scope: "task", task_id: task.id)

      expect([links("task", task.id), mcp_answer("read_task", id: task.id).fetch("record_links")]).to eq([{}, {}])
    end
  end
end
