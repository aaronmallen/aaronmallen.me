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
    file = agents(:create_memory_file, { path: "hanami", scope: "global", **author, session_id: })
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

    it "groups sessions by day, newest first" do
      expect(page.all(".agent-days .day-head .day-note").map(&:text)).to eq(["Today · 1", "Yesterday · 1"])
    end

    it "marks an open session running and an ended one with its length", :aggregate_failures do
      expect(page.find("#agent-session-#{running}")).to have_css(".pill", text: "running")
      expect(page.all(".agent-days .li").last).to have_css(".li-side", text: "30m")
    end

    it "names the brand, repo, branch and counts on a row" do
      expect(page.find("#agent-session-#{running} .li-sub").text)
        .to include("Anthropic claude-opus-5-5", "blog @ index", "0 memory files loaded", "2 memory changes",
                    "1 artifact")
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
    let(:session_id) { start("Index the activities table", task_ids: [task.id], client: "Claude Code 2.4") }

    before do
      agents(:create_memory_file, { path: "preferences", scope: "global" })
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

    it "lists the memory it loaded" do
      expect(field("Memory it loaded")).to have_css(".record-link-title", exact_text: "preferences.md")
    end

    it "lists the memory it changed with the fact's text", :aggregate_failures do
      changed = field("Memory it changed")

      expect(changed.all(".record-link-title").map(&:text)).to eq(["created hanami.md", "added to hanami.md"])
      expect(changed).to have_css(".agent-change-text", text: "Run specs through mise")
    end

    it "lists the artifacts it wrote" do
      expect(field("Artifacts it wrote")).to have_css(".record-link-title", text: "v1 Index plan")
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
      agents(:create_memory_file, { path: "owner-notes", scope: "global" })
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

    it "links to the sessions screen" do
      expect(card.all("a.today-line").map { it["href"] }.uniq).to eq(["/admin/agents/sessions"])
    end
  end
end
