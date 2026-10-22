# frozen_string_literal: true

RSpec.describe "MCP note tools", type: :request do
  let(:work) { create(:note_folder, name: "work") }

  def body_of(id) = note_queries.by_id(id).body

  def mcp_scopes = %w[read notes delete]

  def note_queries = Notes::Slice["repos.note_queries"]

  def owner_note(**) = Notes::Slice["operations.create_note"].call({ body: "", ** }).value!

  describe "list_notes" do
    before do
      owner_note(title: "Zebra")
      Notes::Slice["operations.pin_note"].call(owner_note(title: "Alpha", folder_id: work.id).id, { pinned: true })
    end

    it "lists every note by title with its folder and pin", :aggregate_failures do
      answer = mcp_answer("list_notes")

      expect(answer.fetch("count")).to eq(2)
      expect(answer.fetch("notes").map { it.values_at("title", "folder_id", "pinned") })
        .to eq([["Alpha", work.id, true], ["Zebra", nil, false]])
    end
  end

  describe "search_notes" do
    before do
      owner_note(title: "Retro", body: "What went well")
      owner_note(title: "Invoice", folder_id: create(:note_folder, name: "clients", parent_id: work.id).id)
      owner_note(title: "Gem list", tags: ["ruby"])
    end

    def titles(query) = mcp_answer("search_notes", query:).fetch("notes").map { it.fetch("title") }

    it "finds a note by the words of its body" do
      expect(titles("went well")).to eq(["Retro"])
    end

    it "finds a note by its folder's path" do
      expect(titles("work/clients")).to eq(["Invoice"])
    end

    it "lists the notes a #tag holds" do
      expect(titles("#ruby")).to eq(["Gem list"])
    end
  end

  describe "read_note" do
    let(:note) { owner_note(title: "Plan", body: "See [[Brief]] and [[Later]]", tags: ["ruby"]) }
    let!(:brief) { owner_note(title: "Brief") }
    let!(:kickoff) { owner_note(title: "Kickoff", body: "Read [[Plan]]") }

    it "reads the note with its tags and version" do
      expect(mcp_answer("read_note", id: note.id).values_at("title", "body", "tags", "version"))
        .to eq(["Plan", "See [[Brief]] and [[Later]]", ["ruby"], 1])
    end

    it "lists the notes that link to it and the titles it links", :aggregate_failures do
      answer = mcp_answer("read_note", id: note.id)

      expect(answer.fetch("backlinks")).to eq([{ "id" => kickoff.id, "title" => "Kickoff" }])
      expect(answer.fetch("links_out"))
        .to eq([{ "id" => brief.id, "title" => "Brief" }, { "id" => nil, "title" => "Later" }])
    end

    it "groups the records linked to it by kind" do
      task = create(:task, title: "Write the brief")
      Links::Slice["operations.link_records"].call("note", note.id, { other_kind: "task", other_id: task.id })

      expect(trusted(mcp_answer("read_note", id: note.id).dig("record_links", "task")).map { it.fetch("title") })
        .to eq(["Write the brief"])
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("read_note", id: 999_999)).to eq("no note has the ID 999999")
    end
  end

  describe "create_note" do
    it "writes the note in its folder with its tags, marked untrusted", :aggregate_failures do
      answer = mcp_answer("create_note", title: "Plan", body: "Steps", folder_id: work.id, tags: ["ruby"])

      expect(answer.values_at("title", "body", "folder_id", "tags"))
        .to eq([marked("Plan"), marked("Steps"), work.id, ["ruby"]])
      expect(note_queries.by_id(answer.fetch("id")).written_by_agent).to be(true)
    end

    it "titles a note it is given no title for Untitled" do
      expect(trusted(mcp_answer("create_note")).fetch("title")).to eq("Untitled")
    end

    it "refuses a title another note holds" do
      owner_note(title: "Plan")

      expect(mcp_text("create_note", title: "plan")).to eq("title: another note has that title")
    end

    it "refuses a folder that does not exist" do
      expect(mcp_text("create_note", title: "Plan", folder_id: 999_999)).to eq("folder_id: no note folder has that ID")
    end
  end

  describe "edit_note" do
    let(:note) { owner_note(title: "Plan", body: "Steps") }

    it "saves an edit sent with the version it read and raises the version", :aggregate_failures do
      answer = mcp_answer("edit_note", id: note.id, version: note.version, body: "New steps", tags: ["ruby"])

      expect(answer).to include("body" => marked("New steps"), "tags" => ["ruby"], "version" => note.version + 1)
      expect(body_of(note.id)).to eq("New steps")
    end

    it "refuses an edit against a note that changed since it was read", :aggregate_failures do
      Notes::Slice["operations.edit_note"].call(note.id, { body: "Owner", version: note.version })

      expect(mcp_text("edit_note", id: note.id, version: note.version, body: "Agent"))
        .to eq("version: the note changed since you read it; read_note gives the new version to edit")
      expect(body_of(note.id)).to eq("Owner")
    end

    it "rewrites the links to a new title and counts the notes it rewrote", :aggregate_failures do
      linking = owner_note(title: "Kickoff", body: "Read [[Plan]]")
      answer = mcp_answer("edit_note", id: note.id, version: note.version, title: "Roadmap")

      expect(answer.fetch("relinked")).to eq(1)
      expect(body_of(linking.id)).to eq("Read [[Roadmap]]")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("edit_note", id: 999_999, version: 1, body: "x")).to eq("no note has the ID 999999")
    end
  end

  describe "rename_note" do
    it "retitles the note and marks the notes whose links it rewrote", :aggregate_failures do
      note = owner_note(title: "Plan")
      linking = owner_note(title: "Kickoff", body: "Read [[Plan]]")
      answer = mcp_answer("rename_note", id: note.id, title: "Roadmap")

      expect(answer).to include("title" => marked("Roadmap"), "relinked" => 1)
      expect(mcp_answer("read_note", id: linking.id).fetch("body")).to eq(marked("Read [[Roadmap]]"))
    end

    it "refuses a blank title" do
      expect(mcp_text("rename_note", id: owner_note(title: "Plan").id, title: " "))
        .to eq("title: give the note a title")
    end
  end

  describe "move_note" do
    let(:note) { owner_note(title: "Plan") }

    it "files the note in a folder and back at the top level", :aggregate_failures do
      expect(mcp_answer("move_note", id: note.id, folder_id: work.id).fetch("folder_id")).to eq(work.id)
      expect(mcp_answer("move_note", id: note.id, folder_id: nil).fetch("folder_id")).to be_nil
    end

    it "refuses a folder that does not exist" do
      expect(mcp_text("move_note", id: note.id, folder_id: 999_999)).to eq("folder_id: no note folder has that ID")
    end
  end

  describe "pin_note" do
    it "pins and unpins a note", :aggregate_failures do
      note = owner_note(title: "Plan")

      expect(mcp_answer("pin_note", id: note.id, pinned: true).fetch("pinned")).to be(true)
      expect(mcp_answer("pin_note", id: note.id, pinned: false).fetch("pinned")).to be(false)
    end
  end

  describe "duplicate_note" do
    it "copies the note under a free title" do
      note = owner_note(title: "Plan", body: "Steps", folder_id: work.id)

      expect(mcp_answer("duplicate_note", id: note.id).values_at("title", "body", "folder_id"))
        .to eq(["Plan copy", "Steps", work.id])
    end

    it "keeps the mark of a note an agent wrote" do
      note = mcp_answer("create_note", title: "Plan", body: "Steps")

      expect(mcp_answer("duplicate_note", id: note.fetch("id")).fetch("body")).to eq(marked("Steps"))
    end
  end

  describe "tag_note and untag_note" do
    let(:note) { owner_note(title: "Plan", tags: ["ruby"]) }

    it "adds a tag and keeps the ones it carries" do
      expect(mcp_answer("tag_note", id: note.id, tag: "hanami").fetch("tags")).to eq(%w[hanami ruby])
    end

    it "refuses a tag that is not a slug" do
      expect(mcp_text("tag_note", id: note.id, tag: "Two Words")).to eq("a tag is lowercase words joined by hyphens")
    end

    it "takes a tag off" do
      expect(mcp_answer("untag_note", id: note.id, tag: "ruby").fetch("tags")).to eq([])
    end

    it "refuses to take off a tag the note does not carry" do
      expect(mcp_text("untag_note", id: note.id, tag: "hanami")).to eq("note #{note.id} has no tag hanami")
    end
  end

  describe "delete_note" do
    it "deletes the note for good", :aggregate_failures do
      note = owner_note(title: "Plan")

      expect(mcp_answer("delete_note", id: note.id)).to eq("id" => note.id, "deleted" => true)
      expect(note_queries.by_id(note.id)).to be_nil
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("delete_note", id: 999_999)).to eq("no note has the ID 999999")
    end
  end

  describe "a note the owner saves in the admin" do
    it "comes back plain once the owner saves its title and body" do
      note = mcp_answer("create_note", title: "Plan", body: "Steps")
      Notes::Slice["operations.edit_note"].call(note.fetch("id"), { title: "Plan", body: "Steps", version: 1 })

      expect(mcp_answer("read_note", id: note.fetch("id")).values_at("title", "body")).to eq(%w[Plan Steps])
    end
  end

  describe "list_note_folders" do
    it "lists every folder with its description and parent" do
      clients = create(:note_folder, name: "clients", parent_id: work.id, description: "Paid work")

      folders = mcp_answer("list_note_folders").fetch("folders")

      expect(folders.map { it.values_at("id", "name", "description", "parent_id") })
        .to eq([[clients.id, "clients", "Paid work", work.id], [work.id, "work", "", nil]])
    end
  end

  describe "create_note_folder" do
    it "makes each missing folder on the path and answers the last", :aggregate_failures do
      answer = mcp_answer("create_note_folder", path: "#{work.name}/clients")

      expect(answer).to include("name" => "clients", "parent_id" => work.id)
      expect(note_queries.folders.map(&:name)).to contain_exactly("clients", "work")
    end

    it "refuses an empty path" do
      expect(mcp_text("create_note_folder", path: " / ")).to eq("name the folder first")
    end
  end

  describe "rename_note_folder" do
    it "renames the folder" do
      expect(mcp_answer("rename_note_folder", id: work.id, name: "jobs").fetch("name")).to eq("jobs")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("rename_note_folder", id: 999_999, name: "jobs")).to eq("no note folder has the ID 999999")
    end
  end

  describe "move_note_folder" do
    let(:clients) { create(:note_folder, name: "clients", parent_id: work.id) }

    it "moves the folder to the top level" do
      expect(mcp_answer("move_note_folder", id: clients.id, parent_id: nil).fetch("parent_id")).to be_nil
    end

    it "refuses to move a folder inside one within it" do
      expect(mcp_text("move_note_folder", id: work.id, parent_id: clients.id))
        .to eq("parent_id: a folder cannot move inside itself or a folder within it")
    end
  end

  describe "describe_note_folder" do
    it "sets the folder's description" do
      expect(mcp_answer("describe_note_folder", id: work.id, description: "Paid work").fetch("description"))
        .to eq("Paid work")
    end
  end

  describe "remove_note_folder" do
    let(:clients) { create(:note_folder, name: "clients", parent_id: work.id) }
    let!(:inner) { create(:note_folder, name: "acme", parent_id: clients.id) }
    let!(:note) { owner_note(title: "Invoice", folder_id: clients.id) }

    it "removes the folder and moves its notes and folders up a level", :aggregate_failures do
      expect(mcp_answer("remove_note_folder", id: clients.id)).to eq("id" => clients.id, "removed" => true)
      expect([note_queries.by_id(note.id).folder_id, note_queries.folder_by_id(inner.id).parent_id])
        .to eq([work.id, work.id])
    end
  end

  describe "a token without notes" do
    def mcp_scopes = %w[read write delete]

    it "lists none of the notes tools" do
      mcp_rpc("tools/list")

      expect(mcp_result.fetch("tools").map { it.fetch("name") })
        .not_to include("list_notes", "read_note", "edit_note", "delete_note", "remove_note_folder")
    end

    it "leaves a linked note out of a task's record links" do
      task = create(:task)
      linked = { other_kind: "note", other_id: owner_note(title: "Plan").id }
      Links::Slice["operations.link_records"].call("task", task.id, linked)

      expect(mcp_answer("read_task", id: task.id).fetch("record_links")).not_to have_key("note")
    end

    it "finds no note in search" do
      owner_note(title: "Zeppelin sketches")

      expect(mcp_answer("search", query: "zeppelin").fetch("results")).to be_empty
    end
  end
end
