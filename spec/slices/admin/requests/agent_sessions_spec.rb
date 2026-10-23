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
    let!(:project) { create(:project, name: "The blog", repo: "aaronmallen/blog") }
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

    it "names the brand, project, repo, branch and counts on a row" do
      spans = page.find("#agent-session-#{running} .task-meta").all("span").map { it.text.strip }
      counts = ["0 files read", "0 searches", "2 memory changes", "1 artifact"]

      expect(spans)
        .to match([/\A\d{1,2}:\d{2}–now\z/, "Anthropic claude-opus-5-5", "The blog", "blog @ index", *counts])
    end

    it "marks the project with its icon" do
      expect(page.find("#agent-session-#{running} .task-meta span", text: "The blog")).to have_css("i.fa-cube")
    end

    it "offers the projects sessions ran in as a filter" do
      expect(page.find("select[name='project']").all("option").map { [it.value, it.text] })
        .to eq([["", "Every project"], [project.id.to_s, "The blog"]])
    end

    it "lists only the sessions of the project it filters by", :aggregate_failures do
      get "/admin/agents/sessions", { project: project.id }

      expect(page.all(".agent-days .li").size).to eq(1)
      expect(page).to have_css("#agent-session-#{running}")
      expect(page.find("select[name='project'] option[selected]").value).to eq(project.id.to_s)
    end

    it "keeps the project filter on each row's link" do
      get "/admin/agents/sessions", { project: project.id }

      expect(page.find("#agent-session-#{running} a.li-title")["href"])
        .to eq("/admin/agents/sessions?project=#{project.id}&session=#{running}")
    end

    it "marks the repo with the GitHub icon and the brand with the agent", :aggregate_failures do
      meta = page.find("#agent-session-#{running} .task-meta")

      expect(meta.find("span", text: "blog @ index")).to have_css("i.fa-brands.fa-github")
      expect(meta.find("span", exact_text: "Anthropic claude-opus-5-5")["title"]).to eq("via claude-code")
    end

    it "counts files read, repeats included, and searches run" do
      file = agents(:create_memory_file, { path: "preferences", description: "Notes", scope: "global" })
      2.times { agents(:record_read, running, file.id) }
      agents(:record_search, running, { query: "cache" }, [])
      get "/admin/agents/sessions"

      expect(page.find("#agent-session-#{running} .task-meta").text).to include("2 files read", "1 search")
    end

    it "counts today's sessions, the running ones and every session since the first in the lede" do
      expect(page).to have_css(".page-head-sub", exact_text: "1 session today, 1 still running. 2 in the last 2 days.")
    end

    it "sets the sessions in one card with a day column" do
      expect(page.all(".card.agent-days > .card-body > .activity-day").size).to eq(2)
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
      expect(drawer.find(".agent-session-meta").all("span").map(&:text).first(2))
        .to eq(["claude-code on Anthropic claude-opus-5-5", "via Claude Code 2.4"])
    end

    it "shows the project, repo and branch, and links the project to its sessions", :aggregate_failures do
      project = create(:project, name: "The blog", repo: "aaronmallen/blog")
      get "/admin/agents/sessions", { session: start("Spike", repo: project.repo, branch: "index") }
      meta = drawer.find(".agent-session-meta")

      expect(meta.all(:xpath, "./*").map { it.text.strip }[1, 2]).to eq(["The blog", "aaronmallen/blog @ index"])
      expect(meta).to have_link("The blog", href: "/admin/agents/sessions?project=#{project.id}")
    end

    it "keys the tasks it worked on" do
      expect(field("Worked on")).to have_css(".meta", text: "##{task.id}")
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
        .to eq(["Worked on", "Memory it read", "Memory it changed", "Artifacts it wrote", "Tags"])
    end

    it "lists the memory it changed with the fact's text", :aggregate_failures do
      changed = field("Memory it changed")

      expect(changed.all("a.agent-change > .meta").map(&:text)).to eq(["created hanami.md", "added to hanami.md"])
      expect(changed).to have_css(".agent-change-text", text: "Run specs through mise")
    end

    it "lists a description change under the memory it changed" do
      file = Agents::Slice["relations.memory_files"].where(path: "hanami.md").one
      agents(:describe_memory_file, file[:id], { description: "How we test", **author, session_id: })
      get "/admin/agents/sessions", { session: session_id }

      expect(field("Memory it changed").all(".agent-change > .meta").map(&:text).last)
        .to eq("changed the description of hanami.md")
    end

    it "lists the artifacts it wrote" do
      expect(field("Artifacts it wrote")).to have_css(".record-link-title", text: "· v1 Index plan")
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
      expect(index.all(".memory-line").map(&:text))
        .to eq(["global a deleted file0 factsOld notes", "global hanami.md1 factHanami notes"])
    end

    it "marks a description an agent wrote" do
      file = agents(:create_memory_file, { path: "agent", description: "By an agent", scope: "global", **author })
      get "/admin/agents/sessions", { session: start("Later run") }

      expect(index.find(".memory-line", text: file.path)).to have_css(".agent-mark i.fa-robot")
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
      found = Agents::Slice["operations.search_memory"].call(page, text: query, **filters.except(:repo))
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

      it "marks only the hits an agent wrote" do
        agents(:add_memory_fact, hanami.id, { type: "gotcha", text: "An agent wrote this", **author })
        search("agent")
        open_drawer

        expect(searches.all(".agent-change-text").map { it.has_css?(".agent-mark") }).to eq([false, false, true])
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
          expect(searches.all(".agent-change > .meta").map(&:text))
            .to eq(["hanami.md", "hanami.md · fact since removed"])
        end
      end

      it "keeps a deleted file's hits without a link", :aggregate_failures do
        agents(:delete_memory_file, hanami.id)
        open_drawer

        expect(searches.all("span.agent-change > .meta").map(&:text)).to eq(["a deleted file"] * 2)
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
        .to eq(["Index it started with", "Searches", "Files read", "Memory it changed", "Artifacts it wrote", "Tags"])
    end

    it "shows each read's time, scope and path, repeats included", :aggregate_failures do
      2.times { agents(:record_read, session_id, hanami.id) }
      open_drawer

      expect(reads.all(".agent-read").map(&:text)).to eq(["#{clock} global hanami.md"] * 2)
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
