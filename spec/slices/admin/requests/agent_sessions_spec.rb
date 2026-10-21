# frozen_string_literal: true

RSpec.describe "Admin agent sessions", :frozen_clock, type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, title: "Index the activities table") }

  def agents(name, *, **) = Agents::Slice["operations.#{name}"].call(*, **).value!

  def drawer = page.find_by_id("agent-session")

  def field(label) = drawer.find(".field", text: label)

  def start(title, at: Time.now, **)
    id, = agents(:start_session, { title:, **author, task_ids: [], ** }, at:)
    id
  end

  def work(session_id)
    file = agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "global", **author, session_id: })
    agents(:add_memory_fact, file.id, { type: "gotcha", text: "Run specs through mise", **author, session_id: })
    agents(
      :create_artifact,
      { title: "Index plan", type: "plan", tags: "", body: "Add an index", **author, session_id: },
    )
  end

  before { sign_in_to_admin }

  describe "the list" do
    let!(:running) do
      start("Index the activities table", client: "Claude Code 2.4", repo: "aaronmallen/blog", branch: "index")
    end

    before do
      ended = start("Spec the link check", at: days_ago(1))
      agents(:end_session, ended, at: days_ago(1) + 1_800)
      work(running)
      get "/admin/agents/sessions"
    end

    it "sits under the Agents pill" do
      expect(page).to have_css("a.pill-nav-link[aria-current='page']", text: "Agents")
    end

    it "titles the screen Agents and counts on each tab", :aggregate_failures do
      expect(page).to have_css("h1.page-head-title", exact_text: "Agents")
      expect(page.all("a.screen-tab").map(&:text)).to eq(["memories 1 fact", "artifacts 1", "sessions 1 running"])
    end

    it "groups sessions by day, newest first" do
      expect(page.all(".agent-days .day-head .day-note").map(&:text)).to eq(["Today · 1", "Yesterday · 1"])
    end

    it "marks an open session running and an ended one with its length", :aggregate_failures do
      expect(page.find("#agent-session-#{running}")).to have_css(".pill", text: "running")
      expect(page.all(".agent-days .li").last).to have_css(".li-side", text: "30m")
    end

    it "names the brand, repo, branch and counts on a row" do
      expect(page.find("#agent-session-#{running} .li-sub").text)
        .to include("Anthropic claude-opus-5-5", "blog @ index", "0 files read", "0 searches", "2 memory changes",
                    "1 artifact")
    end

    it "counts files read, repeats included, and searches run" do
      file = agents(:create_memory_file, { path: "preferences", description: "Notes", scope: "global" })
      2.times { agents(:record_read, running, file.id) }
      agents(:record_search, running, { query: "cache" }, [])
      get "/admin/agents/sessions"

      expect(page.find("#agent-session-#{running} .li-sub").text).to include("2 files read", "1 search")
    end

    it "counts today's sessions and the running ones in the lede" do
      expect(page).to have_css(".page-head-sub", text: "1 session today, 1 still running.")
    end

    it "opens no drawer" do
      expect(page).to have_no_css("#agent-session")
    end

    it "links each row to its drawer" do
      expect(page.find("#agent-session-#{running} a.li-title")["href"])
        .to eq("/admin/agents/sessions?session=#{running}")
    end
  end

  describe "the drawer" do
    let!(:session_id) { start("Index the activities table", task_ids: [task.id], client: "Claude Code 2.4") }

    before do
      preferences = agents(:create_memory_file, { path: "preferences", description: "Notes", scope: "global" })
      agents(:record_loads, session_id, [preferences.id])
      work(session_id)
      get "/admin/agents/sessions", { session: session_id }
    end

    it "opens on the session, shown" do
      expect(drawer).to have_css("h3", text: "Index the activities table")
    end

    it "names the agent, model and client" do
      expect(drawer).to have_css(".hint", text: "claude-code on Anthropic claude-opus-5-5 · via Claude Code 2.4")
    end

    it "links the tasks it worked on" do
      expect(field("Worked on")).to have_link("Index the activities table", href: "/admin/tasks/#{task.id}")
    end

    it "keeps the old list for a session from before reads, with a note", :aggregate_failures do
      expect(field("Memory it read").all(".record-link-title").map(&:text)).to eq(["preferences.md"])
      expect(field("Memory it read")).to have_css(".hint", text: "ran before the site recorded searches and reads")
    end

    it "shows no index, searches or files read for a session from before reads" do
      expect(drawer.all(".field > .f").map(&:text))
        .to eq(["Worked on", "Memory it read", "Memory it changed", "Artifacts it wrote"])
    end

    it "lists the memory it changed with the fact's text", :aggregate_failures do
      changed = field("Memory it changed")

      expect(changed.all(".record-link-title").map(&:text)).to eq(["created hanami.md", "added to hanami.md"])
      expect(changed).to have_css(".agent-change-text", text: "Run specs through mise")
    end

    it "lists a description change under the memory it changed" do
      file = Agents::Slice["relations.memory_files"].where(path: "hanami.md").one
      agents(:describe_memory_file, file[:id], { description: "How we test", **author, session_id: })
      get "/admin/agents/sessions", { session: session_id }

      expect(field("Memory it changed").all(".record-link-title").map(&:text).last)
        .to eq("changed the description of hanami.md")
    end

    it "lists the artifacts it wrote" do
      expect(field("Artifacts it wrote")).to have_css(".record-link-title", text: "v1 Index plan")
    end
  end

  describe "the index it started with" do
    let(:hanami) { agents(:create_memory_file, { path: "hanami", description: "Hanami notes", scope: "global" }) }

    def index = field("Index it started with")

    before do
      gone = agents(:create_memory_file, { path: "gone", description: "Old notes", scope: "global" })
      agents(:add_memory_fact, hanami.id, { type: "gotcha", text: "Run specs through mise" })
      session_id = start("Index the activities table", task_ids: [task.id])
      agents(:describe_memory_file, hanami.id, { description: "Newer notes" })
      agents(:delete_memory_file, gone.id)
      get "/admin/agents/sessions", { session: session_id }
    end

    it "follows Worked on" do
      expect(drawer.all(".field > .f").map(&:text).first(2))
        .to eq(["Worked on", "Index it started with"])
    end

    it "lists each line with its scope, fact count and the description the agent got" do
      expect(index.all(".agent-change-text").map(&:text))
        .to eq(["global · 0 facts · Old notes", "global · 1 fact · Hanami notes"])
    end

    it "links a live file to its page" do
      expect(index).to have_link("hanami.md", href: "/admin/agents/memories/#{hanami.id}")
    end

    it "keeps a deleted file's line without a link", :aggregate_failures do
      expect(index).to have_css("span.record-link-title", text: "a deleted file")
      expect(index).to have_no_link("a deleted file")
    end
  end

  describe "searches" do
    let(:hanami) { agents(:create_memory_file, { path: "hanami", description: "Hanami notes", scope: "global" }) }
    let(:session_id) { start("Index the activities table") }

    def clock = Admin::Slice["i18n"].l(Blog::TimeZone.local(Time.now), format: :clock)

    def open_drawer = get("/admin/agents/sessions", { session: session_id })

    def search(query, **filters)
      page = Blog::Structs::Page.new(number: 1, size: 25)
      found = Agents::Slice["operations.search_memory"].call(page, text: query, **filters)
      agents(:record_search, session_id, { query:, **filters }, found.rows)
    end

    def searches = field("Searches")

    it "follows the index" do
      open_drawer

      expect(drawer.all(".field > .f").map(&:text).first(2)).to eq(["Index it started with", "Searches"])
    end

    it "says None. when the session ran no search" do
      open_drawer

      expect(searches).to have_css(".hint", exact_text: "None.")
    end

    context "with a search that found facts" do
      before do
        agents(:add_memory_fact, hanami.id, { type: "gotcha", text: "Run specs through mise" })
        agents(:add_memory_fact, hanami.id, { type: "gotcha", text: "Run lint through mise" })
        search("mise", repo: "aaronmallen/blog", scope: "global")
      end

      it "shows the time, query, filter pills and count" do
        open_drawer

        expect(searches.find(".agent-search-head").all(:xpath, "./span").map(&:text))
          .to eq([clock, "“mise”", "aaronmallen/blog", "global", "2 facts"])
      end

      it "shows each hit in full with its path", :aggregate_failures do
        open_drawer

        expect(searches.all(".agent-change-text").map(&:text)).to eq(["Run specs through mise",
                                                                      "Run lint through mise"])
        expect(searches).to have_link("hanami.md", href: "/admin/agents/memories/#{hanami.id}", count: 2)
      end

      context "when a fact is removed later" do
        before do
          fact = Agents::Slice["relations.memory_facts"].where(text: "Run lint through mise").one
          agents(:remove_memory_fact, hanami.id, fact[:id], {})
          open_drawer
        end

        it "keeps its text" do
          expect(searches.all(".agent-change-text").map(&:text))
            .to eq(["Run specs through mise", "Run lint through mise"])
        end

        it "marks it fact since removed" do
          expect(searches.all(".record-link-row .hint").map(&:text)).to eq(["fact since removed"])
        end
      end

      it "keeps a deleted file's hits without a link", :aggregate_failures do
        agents(:delete_memory_file, hanami.id)
        open_drawer

        expect(searches.all("span.record-link-title").map(&:text)).to eq(["a deleted file"] * 2)
        expect(searches).to have_no_link("a deleted file")
      end
    end

    it "says no filters and No facts matched. for an empty search", :aggregate_failures do
      search("nothing")
      open_drawer

      expect(searches.find(".agent-search-head")).to have_text("no filters")
      expect(searches).to have_text("0 facts")
      expect(searches).to have_css(".hint", text: /\ANo facts matched/)
    end

    it "pills a project and a task by id" do
      search("mise", project_id: 7, task_id: task.id)
      open_drawer

      expect(searches.all(".pill").map(&:text)).to eq(["project 7", "task #{task.id}"])
    end
  end

  describe "files read" do
    let(:hanami) { agents(:create_memory_file, { path: "hanami", description: "Hanami notes", scope: "global" }) }
    let(:session_id) { start("Index the activities table") }

    def clock = Admin::Slice["i18n"].l(Blog::TimeZone.local(Time.now), format: :clock)

    def open_drawer = get("/admin/agents/sessions", { session: session_id })

    def reads = field("Files read")

    it "follows Searches and leaves out the old list", :aggregate_failures do
      agents(:record_read, session_id, hanami.id)
      open_drawer

      expect(drawer.all(".field > .f").map(&:text))
        .to eq(["Index it started with", "Searches", "Files read", "Memory it changed", "Artifacts it wrote"])
    end

    it "shows each read's time, scope and path, repeats included", :aggregate_failures do
      2.times { agents(:record_read, session_id, hanami.id) }
      open_drawer

      expect(reads.all(".agent-read").map(&:text)).to eq(["#{clock}global hanami.md"] * 2)
      expect(reads).to have_link("hanami.md", href: "/admin/agents/memories/#{hanami.id}", count: 2)
    end

    it "says the index and searches were enough when it read no file" do
      open_drawer

      expect(reads).to have_css(".hint", exact_text: "None. The index and searches were enough.")
    end

    it "keeps a deleted file's read without a link", :aggregate_failures do
      agents(:record_read, session_id, hanami.id)
      agents(:delete_memory_file, hanami.id)
      open_drawer

      expect(reads).to have_css("span.record-link-title", text: "a deleted file")
      expect(reads).to have_no_link("a deleted file")
    end
  end

  it "says so when no session exists" do
    get "/admin/agents/sessions"

    expect(page).to have_css(".agent-days", text: "No agent has opened a session yet")
  end

  it "opens no drawer for a session that does not exist" do
    get "/admin/agents/sessions", { session: Blog::Constants::INTEGER_MAX }

    expect(page).to have_no_css("#agent-session")
  end

  describe "the Today card" do
    def card = page.find(".card-title", exact_text: "Agents").ancestor(".card")

    before do
      agents(:end_session, start("Yesterday's run", at: days_ago(1)), at: days_ago(1) + 60)
      work(start("Today's run"))
      agents(:create_memory_file, { path: "owner-notes", description: "Notes", scope: "global" })
      get "/admin"
    end

    it "counts today's sessions, agent memory changes and artifacts written", :aggregate_failures do
      expect(card).to have_css(".today-line", text: "Sessions1 today")
      expect(card).to have_css(".today-line", text: "Memory2 changes today")
      expect(card).to have_css(".today-line", text: "Artifacts1 written today")
    end

    it "shows how many still run" do
      expect(card).to have_css(".pill", text: "1 running")
    end

    it "links its lines to the sessions, memories and artifacts screens" do
      expect(card.all("a.today-line").map { it["href"] })
        .to eq(%w[/admin/agents/sessions /admin/agents/memories /admin/agents/artifacts])
    end
  end

  describe "the Today card's artifacts" do
    def age(id, seconds)
      Agents::Slice["relations.artifact_versions"].where(artifact_id: id).dataset.update(created_at: Time.now - seconds)
    end

    def card = page.find(".card-title", exact_text: "Agents").ancestor(".card")

    def write(title, type: "plan", **)
      agents(:create_artifact, { title:, type:, tags: "", body: "Body", ** })
    end

    context "with more than three written today" do
      before do
        { "Oldest" => 4, "Newest" => 1, "Middle" => 2, "Older" => 3 }.each do |title, seconds|
          age(write(title, **author).id, seconds)
        end
        age(write("Yesterday's plan", **author).id, 2 * 86_400)
        write("Owner's notes")
        get "/admin"
      end

      it "lists the three newest an agent wrote, newest first" do
        expect(card.all(".li-title").map(&:text)).to eq(%w[Newest Middle Older])
      end

      it "links each to its artifact" do
        expect(card.find_link("Newest")["href"]).to match(%r{\A/admin/agents/artifacts/\d+\z})
      end
    end

    it "shows each artifact's type, version, author and time", :aggregate_failures do
      write("Index spec", type: "spec", **author)
      get "/admin"

      meta = card.find(".task-meta")
      expect(meta.find(".task-mark.violet", text: "spec")).to have_css("i.fa-ruler-combined")
      expect(meta.all("span").map(&:text)).to include("v1", "Anthropic claude-opus-5-5", match(/\A\d{1,2}:\d{2}/))
    end

    it "shows no list on a day without artifacts" do
      get "/admin"

      expect(card).to have_no_css(".li")
    end
  end
end
