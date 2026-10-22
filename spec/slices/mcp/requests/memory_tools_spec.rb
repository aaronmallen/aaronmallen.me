# frozen_string_literal: true

RSpec.describe "MCP memory tools", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }

  def add_fact(file, text, type: "convention", **) = mcp_answer("add_memory_fact", id: file, type:, text:, **author, **)

  def create_file(path = "hanami", scope: "global", description: "Notes", **)
    mcp_answer("create_memory_file", path:, description:, scope:, **author, **)
  end

  def history(file) = mcp_answer("read_memory_file", id: file).fetch("history")

  def live_texts(file) = trusted(mcp_answer("read_memory_file", id: file).fetch("facts")).map { it.fetch("text") }

  def mcp_scopes = %w[read agents delete]

  def revert(file, entry) = mcp_text("revert_memory_event", id: file, event_id: entry, **author)

  describe "a file an agent changes" do
    let(:file) { create_file.fetch("id") }
    let(:changes) do
      [
        ["create", nil, nil, "claude-code", "claude-opus-5-5"],
        ["add", "Run tests through mise", nil, "claude-code", "claude-opus-5-5"],
        ["edit", "Run every check through mise", "Run tests through mise", "claude-code", "claude-opus-5-5"],
        ["remove", nil, "Run every check through mise", "codex", "gpt-5"],
      ]
    end

    before do
      fact = add_fact(file, "Run tests through mise").fetch("id")
      mcp_answer("edit_memory_fact", id: file, fact_id: fact, text: "Run every check through mise", **author)
      mcp_answer("remove_memory_fact", id: file, fact_id: fact, agent: "codex", model: "gpt-5")
    end

    it "records each change in the file's history, newest first, with its agent and model" do
      expect(trusted(history(file)).map { it.values_at("op", "text", "was_text", "agent", "model") })
        .to eq(changes.reverse)
    end

    describe "history a page at a time" do
      before { lower_page_size(:mcp, to: 3) }

      def read(page) = mcp_answer("read_memory_file", id: file, page:)

      it "returns the newest page and points to the next", :aggregate_failures do
        expect(read(1).fetch("history").map { it.fetch("op") }).to eq(%w[remove edit add])
        expect(read(1).slice("partial", "next_page")).to eq("partial" => true, "next_page" => 2)
      end

      it "reaches the oldest change on a later page", :aggregate_failures do
        expect(read(2).fetch("history").map { it.fetch("op") }).to eq(%w[create])
        expect(read(2).slice("partial", "next_page")).to eq("partial" => false)
      end
    end
  end

  it "adds .md to a path" do
    expect(create_file("rails/testing").fetch("path")).to eq("rails/testing.md")
  end

  it "marks the text an agent wrote untrusted and leaves the owner's alone" do
    file = create_file.fetch("id")
    add_fact(file, "Prefer Sequel")
    Agents::Slice["operations.add_memory_fact"].call(file, { type: "preference", text: "No emdash" })

    expect(mcp_answer("read_memory_file", id: file).fetch("facts").map { it.fetch("text") })
      .to eq([marked("Prefer Sequel"), "No emdash"])
  end

  describe "read_memory" do
    let(:project) { create(:project, repo: "aaronmallen/blog") }
    let(:task) { create(:task) }
    let(:hanami) { create_file("hanami", scope: "repo", repo: "aaronmallen/blog").fetch("id") }
    let(:preferences) { create_file("preferences").fetch("id") }

    before do
      add_fact(create_file("task-notes", scope: "task", task_id: task.id).fetch("id"), "Mind the index")
      add_fact(create_file("release", scope: "project", project_id: project.id).fetch("id"), "Tag with CalVer")
      add_fact(hanami, "Slices own tables")
      add_fact(preferences, "No emdash", type: "preference")
      create_file("elsewhere", scope: "repo", repo: "aaronmallen/other")
    end

    it "loads global, repo, project and task files in that order, with a project's files for its repo" do
      loaded = mcp_answer("read_memory", repo: "aaronmallen/blog", task_id: task.id)

      expect(loaded.fetch("files").map { it.values_at("scope", "path") }).to eq(
        [%w[global preferences.md], %w[repo hanami.md], %w[project release.md], %w[task task-notes.md]],
      )
    end

    it "indexes each file by its ID, scope, path, description and fact count, with no facts" do
      Agents::Slice["operations.describe_memory_file"].call(hanami, { description: "Ours" })
      index = mcp_answer("read_memory", repo: "aaronmallen/blog").fetch("files").first(2)
      indexed = [preferences, "global", "preferences.md", marked("Notes"), 1], [hanami, "repo", "hanami.md", "Ours", 1]

      expect(index.map { it.values_at("id", "scope", "path", "description", "fact_count") }).to eq(indexed)
    end

    it "leaves removed facts out of the count" do
      fact = add_fact(preferences, "Prefer Sequel").fetch("id")
      mcp_answer("remove_memory_fact", id: preferences, fact_id: fact, **author)

      expect(mcp_answer("read_memory").fetch("files").first.fetch("fact_count")).to eq(1)
    end

    it "loads a repo named in mixed case or with spaces around it as its lower case name" do
      expect(mcp_answer("read_memory", repo: " AaronMallen/Blog ").fetch("files"))
        .to eq(mcp_answer("read_memory", repo: "aaronmallen/blog").fetch("files"))
    end

    it "refuses a repo that is not owner/name" do
      expect(mcp_text("read_memory", repo: "aaronmallen")).to eq("repo: name the repository as owner/name")
    end

    it "loads only the global files when given nothing" do
      expect(mcp_answer("read_memory").fetch("files").map { it.fetch("path") }).to eq(%w[preferences.md])
    end

    it "loads only the global files when the repo is blank" do
      expect(mcp_answer("read_memory", repo: " ").fetch("files").map { it.fetch("path") }).to eq(%w[preferences.md])
    end

    it "loads the files of the project its key names" do
      expect(mcp_answer("read_memory", project: project.key).fetch("files").map { it.fetch("path") })
        .to eq(%w[preferences.md release.md])
    end

    it "refuses a project key that names no project" do
      expect(mcp_text("read_memory", project: "NOPE")).to eq("project: name a project key that exists")
    end

    it "makes a private project for a repo no project holds" do
      mcp_answer("read_memory", repo: "aaronmallen/fresh")

      expect(Projects::Slice["repos.project_queries"].ids_by_repo("aaronmallen/fresh").length).to eq(1)
    end
  end

  describe "search_memory" do
    let(:project) { create(:project, repo: "aaronmallen/blog") }
    let(:task) { create(:task) }
    let(:hanami) { create_file("hanami", scope: "repo", repo: "aaronmallen/blog").fetch("id") }
    let(:preferences) { create_file("preferences").fetch("id") }

    def found(**) = mcp_answer("search_memory", **).fetch("facts")

    def texts(**) = trusted(found(**)).map { it.fetch("text") }

    before do
      add_fact(create_file("task-notes", scope: "task", task_id: task.id).fetch("id"), "Mind the cache index")
      add_fact(create_file("release", scope: "project", project_id: project.id).fetch("id"), "Cache the tag")
      add_fact(hanami, "Slices cache their tables")
      add_fact(preferences, "No emdash in the cache docs", type: "preference")
      add_fact(create_file("elsewhere", scope: "repo", repo: "aaronmallen/other").fetch("id"), "Cache nothing")
    end

    it "returns each live fact that holds the query with its file's ID and path" do
      fact = add_fact(hanami, "Bust the CACHE on deploy").fetch("id")

      expect(found(query: "bust the cache").map { it.values_at("id", "memory_file_id", "path") })
        .to eq([[fact, hanami, "hanami.md"]])
    end

    it "marks the text an agent wrote untrusted and leaves the owner's alone" do
      Agents::Slice["operations.add_memory_fact"].call(preferences, { type: "preference", text: "Owner cache rule" })

      expect(found(query: "cache rule").map { it.fetch("text") }).to eq(["Owner cache rule"])
    end

    it "never matches a removed fact" do
      fact = add_fact(hanami, "Purge the cache").fetch("id")
      mcp_answer("remove_memory_fact", id: hanami, fact_id: fact, **author)

      expect(found(query: "purge")).to be_empty
    end

    it "searches every file when given no filter" do
      expect(texts(query: "cache")).to contain_exactly(
        "Mind the cache index", "Cache the tag", "Slices cache their tables", "No emdash in the cache docs",
        "Cache nothing",
      )
    end

    it "searches the files read_memory lists for a repo" do
      expect(texts(query: "cache", repo: "AaronMallen/Blog"))
        .to contain_exactly("Cache the tag", "Slices cache their tables", "No emdash in the cache docs")
    end

    it "searches the files read_memory lists for a project" do
      expect(texts(query: "cache", project_id: project.id))
        .to contain_exactly("Cache the tag", "No emdash in the cache docs")
    end

    it "searches the files read_memory lists for a project key" do
      expect(texts(query: "cache", project: project.key))
        .to contain_exactly("Cache the tag", "No emdash in the cache docs")
    end

    it "refuses a project key that names no project" do
      expect(mcp_text("search_memory", query: "cache", project: "NOPE"))
        .to eq("project: name a project key that exists")
    end

    it "searches the files read_memory lists for a task" do
      expect(texts(query: "cache", task_id: task.id))
        .to contain_exactly("Mind the cache index", "No emdash in the cache docs")
    end

    it "keeps one scope" do
      expect(texts(query: "cache", scope: "repo", repo: "aaronmallen/blog")).to eq(["Slices cache their tables"])
    end

    it "pages the facts" do
      lower_page_size(:mcp, to: 2)
      first = mcp_answer("search_memory", query: "cache")

      expect([first.values_at("count", "partial", "next_page"), found(query: "cache", page: 3).length])
        .to eq([[2, true, 2], 1])
    end

    it "refuses a blank query" do
      expect(mcp_text("search_memory", query: " ")).to eq("query: write the words to find")
    end

    it "refuses a repo that is not owner/name" do
      expect(mcp_text("search_memory", query: "cache", repo: "aaronmallen"))
        .to eq("repo: name the repository as owner/name")
    end
  end

  describe "reverting" do
    let(:file) { create_file.fetch("id") }
    let(:fact) { add_fact(file, "Use jj").fetch("id") }

    it "takes back an add" do
      fact
      revert(file, entry("add"))

      expect(live_texts(file)).to be_empty
    end

    it "takes back an edit" do
      mcp_answer("edit_memory_fact", id: file, fact_id: fact, type: "gotcha", text: "Use git", **author)
      revert(file, entry("edit"))

      expect(trusted(mcp_answer("read_memory_file", id: file).fetch("facts")).map { it.values_at("type", "text") })
        .to eq([["convention", "Use jj"]])
    end

    def authors(file)
      read = mcp_answer("read_memory_file", id: file)
      facts = read.fetch("facts").map { it.values_at("text", "agent", "model") }
      [facts, read.fetch("history").first.values_at("op", "agent", "model")]
    end

    def entry(change) = history(file).find { it.fetch("op") == change }.fetch("id")

    def owned(name, *, **)
      Agents::Slice["operations.#{name}"].call(*, { **, agent: nil, model: nil, session_id: nil })
    end

    it "gives an agent's fact back to the agent when the owner's edit is reverted" do
      owned(:edit_memory_fact, file, fact, type: "convention", text: "Use git")
      owned(:revert_memory_event, file, entry("edit"))

      expect(authors(file))
        .to eq([[[{ "untrusted" => true, "text" => "Use jj" }, "claude-code", "claude-opus-5-5"]],
                ["revert", nil, nil]])
    end

    it "gives the owner's fact back to the owner when an agent's edit is reverted" do
      owned_fact = owned(:add_memory_fact, file, type: "convention", text: "Use jj").value!.id
      mcp_answer("edit_memory_fact", id: file, fact_id: owned_fact, text: "Use git", **author)
      revert(file, entry("edit"))

      expect(authors(file))
        .to eq([[["Use jj", nil, nil]], ["revert", "claude-code", "claude-opus-5-5"]])
    end

    it "takes back a remove" do
      mcp_answer("remove_memory_fact", id: file, fact_id: fact, **author)
      revert(file, entry("remove"))

      expect(live_texts(file)).to eq(["Use jj"])
    end

    it "refuses a fact that changed since, naming the later entry" do
      added = fact && entry("add")
      mcp_answer("edit_memory_fact", id: file, fact_id: fact, text: "Use jj, not git", **author)

      expect([revert(file, added), live_texts(file)])
        .to eq(["it changed since, in history entry #{entry('edit')}; revert that entry first",
                ["Use jj, not git"]])
    end
  end

  it "adds and edits fact text of any length" do
    file = create_file.fetch("id")
    fact = add_fact(file, "a" * 5000).fetch("id")
    mcp_answer("edit_memory_fact", id: file, fact_id: fact, text: "b" * 6000, **author)

    expect(live_texts(file)).to eq(["b" * 6000])
  end

  it "refuses blank fact text" do
    expect(mcp_text("add_memory_fact", id: create_file.fetch("id"), type: "context", text: " ", **author))
      .to eq("text: write the fact first")
  end

  it "refuses a second file with one path in one scope" do
    create_file("hanami", scope: "repo", repo: "aaronmallen/blog")

    created = mcp_text(
      "create_memory_file", path: "hanami.md", description: "Notes", scope: "repo", repo: "aaronmallen/blog", **author,
    )

    expect(created).to eq("path: a file in this scope already has this path")
  end

  it "keeps one path in two scopes" do
    create_file("hanami")

    expect(create_file("hanami", scope: "repo", repo: "aaronmallen/blog").fetch("scope")).to eq("repo")
  end

  describe "descriptions" do
    let(:file) { create_file(description: "How we test").fetch("id") }

    def describe_file(text, **) = mcp_answer("describe_memory_file", id: file, description: text, **author, **)

    it "refuses a file without one" do
      expect(mcp_text("create_memory_file", path: "hanami", description: " ", scope: "global", **author))
        .to eq("description: describe the file in one line")
    end

    it "refuses one over more than one line" do
      expect(mcp_text("create_memory_file", path: "hanami", description: "One\nTwo", scope: "global", **author))
        .to eq("description: keep the description to one line")
    end

    it "reads back the one an agent wrote marked untrusted" do
      expect(mcp_answer("read_memory_file", id: file).fetch("description")).to eq(marked("How we test"))
    end

    it "changes it" do
      describe_file("When to run which specs")

      expect(mcp_answer("read_memory_file", id: file).fetch("description")).to eq(marked("When to run which specs"))
    end

    it "leaves the owner's unmarked" do
      Agents::Slice["operations.describe_memory_file"].call(file, { description: "Owner notes" })

      expect(mcp_answer("read_memory_file", id: file).fetch("description")).to eq("Owner notes")
    end

    it "refuses a blank change" do
      expect(mcp_text("describe_memory_file", id: file, description: " ", **author))
        .to eq("description: describe the file in one line")
    end

    it "refuses a file that does not exist" do
      expect(mcp_text("describe_memory_file", id: 999_999, description: "Notes", **author))
        .to eq("no memory file has the ID 999999")
    end

    it "adds a describe entry with the old and new text to its history" do
      describe_file("When to run which specs")

      expect(trusted(history(file)).first.values_at("op", "text", "was_text", "agent", "model"))
        .to eq(["describe", "When to run which specs", "How we test", "claude-code", "claude-opus-5-5"])
    end

    it "adds no entry when the description stays the same" do
      describe_file("How we test")

      expect(history(file).map { it.fetch("op") }).to eq(%w[create])
    end

    it "takes back a describe, author and all", :aggregate_failures do
      Agents::Slice["operations.describe_memory_file"].call(file, { description: "Owner notes" })
      revert(file, history(file).first.fetch("id"))

      expect(mcp_answer("read_memory_file", id: file).fetch("description")).to eq(marked("How we test"))
      expect(trusted(history(file)).first.values_at("op", "text", "was_text"))
        .to eq(["revert", "How we test", "Owner notes"])
    end

    it "refuses a describe that a later one changed" do
      describe_file("First")
      first = history(file).first.fetch("id")
      describe_file("Second")

      expect(revert(file, first))
        .to eq("it changed since, in history entry #{history(file).first.fetch('id')}; revert that entry first")
    end
  end

  describe "move_memory_file" do
    let(:file) { create_file.fetch("id") }

    def move(**) = mcp_answer("move_memory_file", id: file, scope: "repo", repo: "aaronmallen/blog", **author, **)

    it "moves a file to another scope" do
      expect(move.values_at("scope", "repo")).to eq(%w[repo aaronmallen/blog])
    end

    it "adds a scope entry to its history with the agent and model" do
      move

      expect(history(file).first.values_at("op", "agent", "model")).to eq(%w[scope claude-code claude-opus-5-5])
    end

    it "refuses a scope that already holds its path" do
      create_file("hanami", scope: "repo", repo: "aaronmallen/blog")

      expect(mcp_text("move_memory_file", id: file, scope: "repo", repo: "aaronmallen/blog", **author))
        .to eq("scope: a file in that scope already has this path")
    end

    it "refuses a repo file with no repo" do
      expect(mcp_text("move_memory_file", id: file, scope: "repo", **author)).to eq("repo: a repo file needs a repo")
    end
  end

  it "deletes a file with its facts" do
    file = create_file.fetch("id")
    add_fact(file, "Gone soon")

    expect([mcp_answer("delete_memory_file", id: file), mcp_text("read_memory_file", id: file)])
      .to eq([{ "id" => file, "deleted" => true }, "no memory file has the ID #{file}"])
  end

  it "deletes the files of a deleted task" do
    task = create(:task)
    file = create_file("notes", scope: "task", task_id: task.id).fetch("id")
    Tasks::Slice["operations.delete_task"].call(task.id)

    expect(mcp_text("read_memory_file", id: file)).to eq("no memory file has the ID #{file}")
  end

  describe "the database" do
    let(:files) { Agents::Slice["db.rom"].relations[:memory_files].dataset }

    it "refuses two files with one path in one scope" do
      files.insert(description: "notes", path: "hanami.md", scope: "repo", repo: "aaronmallen/blog")

      expect { files.insert(description: "notes", path: "hanami.md", scope: "repo", repo: "aaronmallen/blog") }
        .to raise_error(Sequel::UniqueConstraintViolation, /memory_files_scope_path_index/)
    end

    it "refuses two global files with one path" do
      files.insert(description: "notes", path: "hanami.md", scope: "global")

      expect { files.insert(description: "notes", path: "hanami.md", scope: "global") }.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end
end
