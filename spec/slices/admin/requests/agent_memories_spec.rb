# frozen_string_literal: true

RSpec.describe "Admin agent memories", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def agents(name, *, **) = Agents::Slice["operations.#{name}"].call(*, **).value!

  def events(file) = Agents::Slice["relations.memory_events"].where(memory_file_id: file.id).order(:id).to_a

  def facts(file) = Agents::Slice["repos.memory_file_queries"].by_id(file.id).facts

  def file_path(file) = "/admin/agents/memories/#{file.id}"

  def history = page.find(".card", text: "History")

  def t(key, **) = i18n.t(key, **)

  def toast
    follow_redirect!
    page.find("[data-toast]").text
  end

  before { sign_in_to_admin }

  describe "the list" do
    let(:project) { create(:project, name: "Blog", repo: "aaronmallen/blog") }
    let(:task) { create(:task, title: "Index the activities table", status: "in_progress") }

    before do
      global = agents(:create_memory_file, { path: "preferences", description: "Notes", scope: "global" })
      agents(:add_memory_fact, global.id, { type: "gotcha", text: "Run specs through mise", **author })
      agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "repo", repo: "aaronmallen/blog" })
      agents(:create_memory_file, { path: "deploys", description: "Notes", scope: "project", project_id: project.id })
      agents(:create_memory_file, { path: "index", description: "Notes", scope: "task", task_id: task.id })
      agents(:create_memory_file, { path: "other", description: "Notes", scope: "repo", repo: "aaronmallen/other" })
    end

    def titles = page.all(".card-title").map(&:text)

    it "sits under the Agents pill as the first screen", :aggregate_failures do
      get "/admin/agents/memories"

      expect(page).to have_css("a.pill-nav-link[aria-current='page'][href='/admin/agents/memories']", text: "Agents")
      expect(page).to have_css(".screen-tabs a[aria-current='page']", text: "memories")
    end

    it "groups files by scope, global first" do
      get "/admin/agents/memories"

      expect(titles.first(5).map { it.split(" · ").first }).to eq(%w[Global Repo Repo Project Task])
    end

    it "names each group by its target" do
      get "/admin/agents/memories"

      expect(titles).to include("Repo · aaronmallen/blog", "Project · Blog", "Task · Index the activities table")
    end

    it "filters by scope", :aggregate_failures do
      get "/admin/agents/memories", { scope: "repo" }

      expect(page.all(".li-title").map(&:text)).to eq(%w[hanami.md other.md])
      expect(page).to have_css(".seg a[aria-current='page']", text: "Repos · 2")
    end

    it "searches fact text and shows the facts it found", :aggregate_failures do
      get "/admin/agents/memories", { query: "through MISE" }

      expect(page.all(".li-title").map(&:text)).to eq(%w[preferences.md])
      expect(page).to have_css(".memory-hit", text: "Run specs through mise")
    end

    it "says so when nothing matches" do
      get "/admin/agents/memories", { query: "zeppelin" }

      expect(page).to have_css(".empty", text: t("ui.views.agents.memories.no_match", query: "zeppelin"))
    end

    it "lists what a session in the chosen repo loads, linked to each file" do
      get "/admin/agents/memories", { repo: "aaronmallen/blog" }

      expect(page.find(".card", text: "What a session loads").all("a.record-link-title").map(&:text))
        .to eq(["global preferences.md", "repo hanami.md", "project deploys.md"])
    end

    it "offers any open task as a scope, but no closed one", :aggregate_failures do
      create(:task, title: "Write the release notes")
      create(:task, :canceled, title: "Drop the old feed")
      get "/admin/agents/memories"

      expect(page).to have_css("option", text: "Task · Write the release notes", visible: :all)
      expect(page).to have_no_css("option", text: "Task · Drop the old feed", visible: :all)
    end

    it "notes what each group loads for" do
      get "/admin/agents/memories"

      expect(page.find(".card", text: "Repo · aaronmallen/blog")).to have_text("loads for sessions in this repo")
    end

    it "picks the first repo when none is chosen" do
      get "/admin/agents/memories"

      expect(page).to have_select("Working in", selected: "aaronmallen/blog")
    end
  end

  describe "its queries" do
    let(:files) { Agents::Slice["repos.memory_file_queries"] }
    let(:projects) { Projects::Slice["repos.project_queries"] }

    before do
      allow(files).to receive(:repos).and_call_original
      allow(projects).to receive(:live_by_name).and_call_original
      %w[repos.memory_file_queries agents.repos.memory_file_queries].each { replace_component(it, files) }
      %w[repos.project_queries projects.repos.project_queries].each { replace_component(it, projects) }
    end

    it "reads the repos and live projects once a load", :aggregate_failures do
      get "/admin/agents/memories"

      expect(files).to have_received(:repos).once
      expect(projects).to have_received(:live_by_name).once
    end
  end

  describe "a new file" do
    it "creates it as the owner and opens it", :aggregate_failures do
      admin_post("/admin/agents/memories", memory_file: { path: "testing", description: "Tests", scope: "global" })
      file = Agents::Slice["repos.memory_file_queries"].listed.last

      expect(file).to have_attributes(path: "testing.md", description: "Tests", description_agent: nil)
      expect(last_response.location).to end_with(file_path(file))
      expect(events(file).map { [it[:op], it[:agent]] }).to eq([["create", nil]])
    end

    it "refuses a bad path and keeps the form open", :aggregate_failures do
      admin_post("/admin/agents/memories", memory_file: { path: "bad path!", description: "Notes", scope: "global" })

      expect(last_response.status).to eq(422)
      expect(page).to have_css("details.memory-new[open] .field-error", text: "Use letters, digits")
    end

    it "refuses a blank description and keeps the form open" do
      admin_post("/admin/agents/memories", memory_file: { path: "testing", description: " ", scope: "global" })

      expect(page).to have_css(
        "details.memory-new[open] .field-error", text: t("ui.components.agents.memory_field_error.description.blank"),
      )
    end

    it "refuses a path the scope already holds" do
      agents(:create_memory_file, { path: "testing", description: "Notes", scope: "global" })
      admin_post("/admin/agents/memories", memory_file: { path: "testing", description: "Notes", scope: "global" })

      expect(page).to have_css(".field-error", text: t("ui.components.agents.memory_field_error.path.taken"))
    end

    it "refuses a task that is gone" do
      gone = "task:#{Blog::Constants::INTEGER_MAX}"
      admin_post("/admin/agents/memories", memory_file: { path: "testing", description: "Notes", scope: gone })

      expect(page).to have_css("#memory-scope-error", text: "That record is gone")
    end
  end

  describe "a file" do
    let(:file) { agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "global" }) }
    let(:fact) { agents(:add_memory_fact, file.id, { type: "gotcha", text: "Run specs through mise", **author }) }

    it "shows its description" do
      get file_path(file)

      expect(page).to have_css(".page-head", text: "Notes")
    end

    it "shows its facts under their type with who wrote them", :aggregate_failures do
      fact
      get file_path(file)

      expect(page).to have_css("h3.memory-type", text: "Gotchas")
      expect(page.find("#memory-fact-#{fact.id}")).to have_text("claude-code on Anthropic claude-opus-5-5")
    end

    it "lists its facts in fact type order" do
      %w[context gotcha preference].each { agents(:add_memory_fact, file.id, { type: it, text: "A #{it}", **author }) }
      get file_path(file)

      expect(page.all("h3.memory-type").map(&:text)).to eq(%w[Preferences Gotchas Context])
    end

    it "names what loads it in the lede" do
      moved = agents(
        :create_memory_file, { path: "hanami", description: "Notes", scope: "repo", repo: "aaronmallen/blog" },
      )
      get file_path(moved)

      expect(page).to have_text(t("memories_page.loads_for.named.repo", name: "aaronmallen/blog"))
    end

    it "shows the markdown start_session hands an agent" do
      fact
      _, loaded = agents(:start_session, { title: "Spike", **author, task_ids: [] })
      get file_path(file), { view: "loaded" }

      expect(page.find("pre.memory-raw").text).to eq(loaded.find { it.id == file.id }.markdown)
    end

    it "escapes what an agent wrote" do
      agents(:add_memory_fact, file.id, { type: "context", text: "<script>alert(1)</script>", **author })
      get file_path(file)

      expect(last_response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end

    it "answers 404 for a file that does not exist" do
      get "/admin/agents/memories/#{Blog::Constants::INTEGER_MAX}"

      expect(last_response.status).to eq(404)
    end

    describe "as the owner" do
      before do
        admin_post("#{file_path(file)}/facts", fact: { type: "convention", text: "Use jj" })
        added = facts(file).last
        admin_post("#{file_path(file)}/facts/#{added.id}", fact: { type: "convention", text: "Use jj, not git" })
        admin_post("#{file_path(file)}/facts/#{added.id}/delete")
      end

      it "adds, edits and removes a fact" do
        expect(events(file).map { [it[:op], it[:text] || it[:was_text]] })
          .to eq([["create", nil], ["add", "Use jj"], ["edit", "Use jj, not git"], ["remove", "Use jj, not git"]])
      end

      it "leaves the file empty" do
        expect(facts(file)).to be_empty
      end

      it "names the owner as the author of each change" do
        expect(events(file).map { it[:agent] }.uniq).to eq([nil])
      end
    end

    it "reverts a removal" do
      admin_post("#{file_path(file)}/facts/#{fact.id}/delete")
      admin_post("#{file_path(file)}/history/#{events(file).last[:id]}/revert")

      expect(facts(file).map(&:text)).to eq(["Run specs through mise"])
    end

    it "reverts an edit back to the old text and the agent that wrote it", :aggregate_failures do
      admin_post("#{file_path(file)}/facts/#{fact.id}", fact: { type: "gotcha", text: "Run specs with rspec" })
      admin_post("#{file_path(file)}/history/#{events(file).last[:id]}/revert")

      expect(facts(file).map { [it.text, it.agent, it.model] })
        .to eq([["Run specs through mise", "claude-code", "claude-opus-5-5"]])
      expect(events(file).last.values_at(:op, :agent, :model)).to eq(["revert", nil, nil])
    end

    it "reverts an add, and the next session no longer loads it" do
      fact
      admin_post("#{file_path(file)}/history/#{events(file).last[:id]}/revert")
      _, loaded = agents(:start_session, { title: "Spike", **author, task_ids: [] })

      expect(loaded.find { it.id == file.id }.facts).to be_empty
    end

    it "says so when a later change touched the fact" do
      fact
      add = events(file).last
      agents(:edit_memory_fact, file.id, fact.id, { type: "gotcha", text: "Use mise", **author })
      admin_post("#{file_path(file)}/history/#{add[:id]}/revert")

      expect(toast).to eq(t("memories_page.toasts.stale"))
    end

    it "adds and edits fact text of any length" do
      admin_post("#{file_path(file)}/facts", fact: { type: "gotcha", text: "a" * 5000 })
      admin_post("#{file_path(file)}/facts/#{facts(file).last.id}", fact: { type: "gotcha", text: "b" * 6000 })

      expect(facts(file).map(&:text)).to eq(["b" * 6000])
    end

    it "refuses a blank fact and keeps what was typed", :aggregate_failures do
      admin_post("#{file_path(file)}/facts", fact: { type: "gotcha", text: " " })

      expect(last_response.status).to eq(422)
      expect(page).to have_css(
        "#memory-new-fact-text-error", text: t("ui.components.agents.memory_field_error.text.blank"),
      )
    end

    it "refuses a blank edit and opens that fact's form" do
      admin_post("#{file_path(file)}/facts/#{fact.id}", fact: { type: "gotcha", text: " " })

      expect(page).to have_css("#memory-fact-#{fact.id} details.memory-edit[open] .field-error")
    end

    it "offers a revert only on each fact's latest change", :aggregate_failures do
      agents(:edit_memory_fact, file.id, fact.id, { type: "gotcha", text: "Use mise", **author })
      get file_path(file)

      add, edit = events(file).last(2)
      expect(page).to have_no_css("#memory-event-#{add[:id]} form")
      expect(page).to have_css("#memory-event-#{edit[:id]} form button", text: "Revert")
    end

    it "marks a reverted entry" do
      fact
      add = events(file).last
      admin_post("#{file_path(file)}/history/#{add[:id]}/revert")
      get file_path(file)

      expect(page.find("#memory-event-#{add[:id]}")).to have_css(".meta", text: "reverted")
    end

    it "links each history entry to its session" do
      id, = agents(:start_session, { title: "Spike", **author, task_ids: [] })
      agents(:add_memory_fact, file.id, { type: "gotcha", text: "Use mise", **author, session_id: id })
      get file_path(file)

      expect(history).to have_link("Session", href: "/admin/agents/sessions?session=#{id}")
    end

    it "names who made each change", :aggregate_failures do
      fact
      admin_post("#{file_path(file)}/facts", fact: { type: "convention", text: "Use jj" })
      get file_path(file)

      expect(history.all(".memory-event-what strong").map(&:text))
        .to eq(["You", "claude-code on Anthropic claude-opus-5-5", "You"])
    end

    it "moves it to another scope and writes a scope entry", :aggregate_failures do
      admin_post("#{file_path(file)}/scope", memory_file: { scope: "repo:aaronmallen/blog" })

      expect(Agents::Slice["repos.memory_file_queries"].by_id(file.id))
        .to have_attributes(scope: "repo", repo: "aaronmallen/blog")
      expect(events(file).last).to include(op: "scope", agent: nil)
    end

    it "writes no scope entry when the scope stays" do
      admin_post("#{file_path(file)}/scope", memory_file: { scope: "global" })

      expect(events(file).map { it[:op] }).to eq(%w[create])
    end

    it "refuses a scope that already holds the path" do
      agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "repo", repo: "aaronmallen/blog" })
      admin_post("#{file_path(file)}/scope", memory_file: { scope: "repo:aaronmallen/blog" })

      expect(page).to have_css("#memory-scope-error", text: t("ui.components.agents.memory_field_error.scope.taken"))
    end

    it "deletes it", :aggregate_failures do
      admin_post("#{file_path(file)}/delete")

      expect(last_response.location).to end_with("/admin/agents/memories")
      expect(Agents::Slice["repos.memory_file_queries"].by_id(file.id)).to be_nil
    end
  end

  describe "its history" do
    let(:file) { agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "global" }) }

    def add(text) = agents(:add_memory_fact, file.id, { type: "gotcha", text:, **author })

    def entry(event) = history.find("#memory-event-#{event[:id]}")

    def shown = history.all(".memory-event").map { it[:id] }

    before do
      lower_page_size(:admin, to: 2)
      add("Run specs through mise")
      add("Use jj")
      admin_post("#{file_path(file)}/history/#{events(file)[1][:id]}/revert")
    end

    it "shows the newest page, counts every entry and links to older ones", :aggregate_failures do
      get file_path(file)

      expect(shown).to eq(events(file).last(2).reverse.map { "memory-event-#{it[:id]}" })
      expect(history.find(".card-title")).to have_text("4")
      expect(history).to have_css("a[rel='next'][href='#{file_path(file)}?page=2']")
    end

    it "keeps the loaded view when it links to older entries" do
      get file_path(file), { view: "loaded" }

      expect(history).to have_css("a[rel='next'][href='#{file_path(file)}?view=loaded&page=2']")
    end

    it "reaches the oldest entry on a later page" do
      get file_path(file), { page: 2 }

      expect(shown).to eq(events(file).first(2).reverse.map { "memory-event-#{it[:id]}" })
    end

    it "names what a revert undid when that entry sits on another page" do
      get file_path(file)

      expect(entry(events(file).last)).to have_text("reverted an addition")
    end

    it "marks an entry reverted from a newer page and offers no revert on it", :aggregate_failures do
      get file_path(file), { page: 2 }

      expect(entry(events(file)[1])).to have_css(".meta", text: "reverted")
      expect(entry(events(file)[1])).to have_no_css("form")
    end

    it "answers 404 past the last page" do
      get file_path(file), { page: 3 }

      expect(last_response.status).to eq(404)
    end
  end

  describe "its records" do
    let(:file) { agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "global" }) }
    let(:task) { create(:task, title: "Index the activities table") }

    def link_task = admin_post("#{file_path(file)}/records", record: { other_kind: "task", other_id: task.id.to_s })

    def linked = Links::Slice["repos.record_link_queries"].for_record("memory_file", file.id)

    def section = page.find(".record-links")

    it "links a task" do
      link_task

      expect(linked.fetch("task").map(&:id)).to eq([task.id])
    end

    it "lists a linked task with a link to it" do
      link_task
      get file_path(file)

      expect(section).to have_link("Index the activities table", href: "/admin/tasks/#{task.id}")
    end

    it "finds records to link" do
      task.then { get file_path(file), { record_q: "activities" } }

      expect(section).to have_css("[name='record[other_id]'][value='#{task.id}']", visible: :all)
    end

    it "unlinks a task" do
      link_task
      admin_post("/admin/records/memory_file/#{file.id}/links/task/#{task.id}/delete")

      expect(linked).to be_empty
    end

    it "draws the task its scope names without a remove button", :aggregate_failures do
      scoped = agents(:create_memory_file, { path: "index", description: "Notes", scope: "task", task_id: task.id })
      get file_path(scoped)

      expect(section).to have_link("Index the activities table")
      expect(section).to have_no_css(".record-link-row form")
    end

    it "keeps the task its scope names and comes back to the file", :aggregate_failures do
      scoped = agents(:create_memory_file, { path: "index", description: "Notes", scope: "task", task_id: task.id })
      admin_post("/admin/records/memory_file/#{scoped.id}/links/task/#{task.id}/delete")

      expect(last_response).to be_redirect.and have_attributes(location: end_with(file_path(scoped)))
      follow_redirect!
      expect(page.find("[data-toast]").text).to eq(Admin::Slice["i18n"].t("record_links.toasts.scoped"))
    end
  end

  describe "the links into it" do
    let!(:file) { agents(:create_memory_file, { path: "hanami", description: "Notes", scope: "global" }) }

    it "links the Today card's Memory line" do
      get "/admin"

      expect(page.find(".today-line", text: "Memory")[:href]).to eq("/admin/agents/memories")
    end

    def session_links = page.find_by_id("agent-session").all("a[href='#{file_path(file)}']").map(&:text)

    it "links the memory a session read and changed" do
      id, = agents(:start_session, { title: "Spike", **author, task_ids: [] })
      agents(:record_loads, id, [file.id])
      agents(:add_memory_fact, file.id, { type: "gotcha", text: "Use mise", **author, session_id: id })
      get "/admin/agents/sessions", { session: id }

      expect(session_links).to eq(["hanami.md", "added to hanami.md"])
    end

    it "links a memory file in a task's links" do
      task = create(:task)
      linked = agents(:create_memory_file, { path: "index", description: "Notes", scope: "task", task_id: task.id })
      get "/admin/tasks/#{task.id}"

      expect(page).to have_link("index.md", href: file_path(linked))
    end
  end
end
