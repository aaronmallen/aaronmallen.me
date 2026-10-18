# frozen_string_literal: true

RSpec.describe "MCP artifact tools", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }

  def create_artifact(title = "Index the activities table", type: "plan", body: "## Steps", **)
    mcp_answer("create_artifact", title:, type:, body:, **author, **)
  end

  def mcp_scopes = %w[read agents delete]

  def versions(id) = trusted(mcp_answer("read_artifact", id:).fetch("versions"))

  describe "an artifact an agent edits" do
    let(:id) { create_artifact(note: "First pass").fetch("id") }
    let(:written) do
      [
        [1, "claude-code", "claude-opus-5-5", "First pass"], [2, "claude-code", "claude-opus-5-5", "Added a step"],
        [3, "codex", "gpt-5", nil],
      ]
    end

    before do
      mcp_answer("update_artifact", id:, body: "## Steps\n\n1. Add the index", note: "Added a step", **author)
      mcp_answer("update_artifact", id:, body: "## Done", agent: "codex", model: "gpt-5")
    end

    it "adds a version for each body with its agent, model and note" do
      expect(versions(id).map { it.values_at("number", "agent", "model", "note") }).to eq(written)
    end

    it "gives the latest body, or the body of the version named" do
      bodies = [mcp_answer("read_artifact", id:), mcp_answer("read_artifact", id:, version: 2)].map { it.fetch("body") }

      expect(trusted(bodies)).to eq(["## Done", "## Steps\n\n1. Add the index"])
    end
  end

  it "adds no version for a title, type or tag change" do
    id = create_artifact.fetch("id")
    changed = mcp_answer("update_artifact", id:, title: "Handoff", type: "handoff", tags: %w[site perf], **author)

    expect([trusted(changed.values_at("title", "type", "tags", "version")), versions(id).size])
      .to eq([["Handoff", "handoff", %w[site perf], 1], 1])
  end

  it "adds no version when the body stays the same" do
    id = create_artifact.fetch("id")
    mcp_answer("update_artifact", id:, body: "## Steps", note: "Nothing new", **author)

    expect(versions(id).size).to eq(1)
  end

  it "restores an old version as a new one with its body" do
    id = create_artifact.fetch("id")
    mcp_answer("update_artifact", id:, body: "## Wrong turn", **author)
    restored = mcp_answer("restore_artifact_version", id:, version: 1, **author)

    expect([trusted(restored.fetch("body")), versions(id).map { it.values_at("number", "note") }])
      .to eq(["## Steps", [[1, nil], [2, nil], [3, "Restored version 1"]]])
  end

  it "refuses to restore a version the artifact does not have" do
    id = create_artifact.fetch("id")

    expect(mcp_text("restore_artifact_version", id:, version: 4, **author)).to eq("artifact #{id} has no version 4")
  end

  describe "an artifact the owner edits after an agent" do
    let(:id) { create_artifact(note: "Draft").fetch("id") }

    before do
      Agents::Slice["operations.update_artifact"].call(
        id, { title: "Index the activities table", type: "plan", tags: "", body: "## Owner's", note: "Mine" },
      )
    end

    it "marks the body and note the agent wrote untrusted" do
      read = mcp_answer("read_artifact", id:, version: 1)

      expect([read.fetch("body"), read.fetch("versions").map { it.fetch("note") }])
        .to eq([marked("## Steps"), [marked("Draft"), "Mine"]])
    end

    it "leaves the owner's body alone" do
      expect(mcp_answer("read_artifact", id:).fetch("body")).to eq("## Owner's")
    end

    it "keeps the title the agent set marked untrusted" do
      expect(mcp_answer("read_artifact", id:).fetch("title")).to eq(marked("Index the activities table"))
    end
  end

  it "leaves a title the owner set alone" do
    id = create_artifact.fetch("id")
    owned = { title: "Owner's plan", type: "plan", tags: "", body: "## Steps" }
    Agents::Slice["operations.update_artifact"].call(id, owned)

    expect(mcp_answer("list_artifacts").fetch("artifacts").map { it.fetch("title") }).to eq(["Owner's plan"])
  end

  it "marks a title an agent sets on an owner's artifact" do
    owned = { title: "Mine", type: "plan", tags: "", body: "## Steps" }
    id = Agents::Slice["operations.create_artifact"].call(owned).value!.id
    mcp_answer("update_artifact", id:, title: "Theirs", **author)

    expect(mcp_answer("read_artifact", id:).fetch("title")).to eq(marked("Theirs"))
  end

  describe "listing" do
    before do
      create_artifact("Index the activities table", body: "Add a composite index", tags: %w[perf])
      create_artifact("Webmention receiver", type: "spec", body: "Reject sources without a link back")
      create_artifact("Ractor notes", type: "research", body: "Contexts are not shareable", tags: %w[ractors])
    end

    def titles(**) = trusted(mcp_answer("list_artifacts", **).fetch("artifacts").map { it.fetch("title") })

    it "lists every artifact, last changed first" do
      expect(titles).to eq(["Ractor notes", "Webmention receiver", "Index the activities table"])
    end

    it "filters by type" do
      expect(titles(type: "spec")).to eq(["Webmention receiver"])
    end

    it "searches the title, the latest body and the tags" do
      expect([titles(query: "receiver"), titles(query: "composite"), titles(query: "ractors")])
        .to eq([["Webmention receiver"], ["Index the activities table"], ["Ractor notes"]])
    end

    it "searches only the latest body" do
      id = mcp_answer("list_artifacts", type: "spec").fetch("artifacts").first.fetch("id")
      mcp_answer("update_artifact", id:, body: "Accept every source", **author)

      expect([titles(query: "link back"), titles(query: "every source")]).to eq([[], ["Webmention receiver"]])
    end
  end

  it "deletes an artifact with every version" do
    id = create_artifact.fetch("id")
    mcp_answer("update_artifact", id:, body: "## Two", **author)
    versions = Agents::Slice["db.rom"].relations[:artifact_versions].dataset.where(artifact_id: id)

    expect([mcp_answer("delete_artifact", id:), mcp_text("read_artifact", id:), versions.count])
      .to eq([{ "id" => id, "deleted" => true }, "no artifact has the ID #{id}", 0])
  end

  it "refuses a body over 100,000 characters" do
    expect(mcp_text("create_artifact", title: "Big", type: "notes", body: "a" * 100_001, **author))
      .to eq("body: keep a body to 100000 characters")
  end

  it "refuses a title over 200 characters" do
    expect(mcp_text("create_artifact", title: "a" * 201, type: "notes", body: "## Steps", **author))
      .to eq("title: keep a title to 200 characters")
  end

  it "refuses a note over 200 characters" do
    id = create_artifact.fetch("id")

    expect(mcp_text("update_artifact", id:, body: "## New", note: "a" * 201, **author))
      .to eq("note: keep a note to 200 characters")
  end

  describe "the database" do
    let(:versions) { Agents::Slice["db.rom"].relations[:artifact_versions].dataset }
    let(:id) { create_artifact.fetch("id") }

    it "numbers versions in order, whatever number an insert gives" do
      versions.insert(artifact_id: id, number: 7, body: "## Again")

      expect(versions.where(artifact_id: id).order(:number).select_map(:number)).to eq([1, 2])
    end

    it "refuses a title over 200 characters" do
      artifacts = Agents::Slice["db.rom"].relations[:artifacts].dataset

      expect { artifacts.insert(title: "a" * 201, type: "plan") }
        .to raise_error(Sequel::CheckConstraintViolation, /artifacts_title_length_check/)
    end

    it "refuses two versions with one number" do
      versions.insert(artifact_id: id, body: "## Again")

      expect { versions.where(artifact_id: id, number: 2).update(number: 1) }
        .to raise_error(Sequel::UniqueConstraintViolation, /artifact_versions_artifact_id_number_index/)
    end
  end
end
