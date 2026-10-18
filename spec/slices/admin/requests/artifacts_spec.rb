# frozen_string_literal: true

RSpec.describe "Admin artifacts", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def agents(name, *, **) = Agents::Slice["operations.#{name}"].call(*, **).value!

  def artifact(title = "Plan the index", body: "Add an index", **)
    agents(:create_artifact, { title:, type: "plan", tags: "", body:, **author, ** })
  end

  def reload(id) = Agents::Slice["repos.artifact_queries"].by_id(id)

  def titles = page.all(".li .li-title").map(&:text)

  def versions(id) = Agents::Slice["repos.artifact_queries"].versions(id)

  before { sign_in_to_admin }

  describe "the list" do
    let!(:plan) { artifact("Plan the index", tags: "db, perf") }
    let!(:notes) { agents(:create_artifact, { title: "Notes on caching", type: "notes", tags: "", body: "Use Redis" }) }

    before do
      agents(:update_artifact, plan.id, { title: plan.title, type: "plan", tags: "db", body: "v2" })
      age(plan.id, 1, 300)
      age(notes.id, 1, 120)
      age(plan.id, 2, 60)
    end

    def age(id, number, seconds)
      Agents::Slice["relations.artifact_versions"].where(artifact_id: id, number:).dataset
                                                  .update(created_at: Time.now - seconds)
    end

    it "sits under the Agents pill" do
      get "/admin/agents/artifacts"

      expect(page).to have_css("a.pill-nav-link[aria-current='page']", text: "Agents")
    end

    it "sorts by the latest version" do
      get "/admin/agents/artifacts"

      expect(titles).to eq(["Plan the index", "Notes on caching"])
    end

    it "names each row's type, version, author and tags" do
      get "/admin/agents/artifacts"

      expect(page.all(".li-sub").map(&:text))
        .to match([/\Aplan · v2 · .+ by you · #db\z/, /\Anotes · v1 · .+ by you\z/])
    end

    it "filters by type" do
      get "/admin/agents/artifacts", type: "notes"

      expect(titles).to eq(["Notes on caching"])
    end

    it "shows each type as a pill that keeps the search" do
      get "/admin/agents/artifacts", type: "notes", search: "redis"

      expect(page).to have_link("notes 1", href: "/admin/agents/artifacts?type=notes&search=redis")
        .and have_css(".search-kind[aria-current=page]", exact_text: "notes 1")
        .and have_link("All 2", href: "/admin/agents/artifacts?search=redis")
    end

    it "searches the body" do
      get "/admin/agents/artifacts", search: "redis"

      expect(titles).to eq(["Notes on caching"])
    end

    it "searches the tags" do
      get "/admin/agents/artifacts", search: "db"

      expect(titles).to eq(["Plan the index"])
    end

    it "says so when nothing matches" do
      get "/admin/agents/artifacts", search: "nothing like it"

      expect(page).to have_css(".empty", text: i18n.t("ui.views.agents.artifacts.index.no_match"))
    end

    it "counts the artifacts in the lede" do
      get "/admin/agents/artifacts"

      expect(page).to have_css(".page-head-sub", text: "2 artifacts, 2 updated this week.")
    end

    it "links to the new artifact form" do
      get "/admin/agents/artifacts"

      expect(page).to have_link("New artifact", href: "/admin/agents/artifacts/new")
    end
  end

  it "says so when no artifact exists" do
    get "/admin/agents/artifacts"

    expect(page).to have_css(".empty", text: i18n.t("ui.views.agents.artifacts.index.empty"))
  end

  describe "creating one" do
    it "draws a form that posts without script", :aggregate_failures do
      get "/admin/agents/artifacts/new"

      expect(page).to have_css("form[method='post'][action='/admin/agents/artifacts'] textarea[name='artifact[body]']")
      expect(page).to have_css("select[name='artifact[type]'] option[selected][value='plan']")
      expect(page).to have_css(".edit-split .preview")
    end

    it "creates it as the owner and opens it", :aggregate_failures do
      admin_post "/admin/agents/artifacts", artifact: { title: "My plan", type: "spec", tags: "site", body: "# Hi" }

      created = reload(Agents::Slice["relations.artifacts"].dataset.max(:id))
      expect(last_response.location).to end_with("/admin/agents/artifacts/#{created.id}")
      expect(versions(created.id).map { [it.number, it.agent] }).to eq([[1, nil]])
      expect(created.tags).to eq(%w[site])
    end

    it "refuses a blank body and keeps what was typed", :aggregate_failures do
      admin_post "/admin/agents/artifacts", artifact: { title: "My plan", type: "spec", tags: "", body: " " }

      expect(last_response.status).to eq(422)
      expect(page.find_by_id("artifact-body-error").text)
        .to eq(i18n.t("ui.components.agents.artifact_field_error.body.blank"))
      expect(page).to have_field("artifact[title]", with: "My plan")
    end
  end

  describe "the page" do
    let(:found) { artifact(body: "# Plan\n\n**bold** <script>alert(1)</script>") }

    it "renders agent markdown sanitized", :aggregate_failures do
      get "/admin/agents/artifacts/#{found.id}"

      expect(page).to have_css(".markdown-body strong", text: "bold")
      expect(page).to have_no_css(".markdown-body script")
    end

    it "lists versions, newest first, with the author and note" do
      agents(:update_artifact, found.id, { title: found.title, type: "plan", tags: "", body: "Next", note: "Tidied" })
      get "/admin/agents/artifacts/#{found.id}"

      expect(page.all(".artifact-version").map(&:text))
        .to match([/\Av2you · .+ · currentTidied\z/, /\Av1Anthropic claude-opus-5-5 · .+\z/])
    end

    it "shows no banner on the latest version" do
      get "/admin/agents/artifacts/#{found.id}"

      expect(page).to have_no_css(".post-banner")
    end

    it "answers not found for an artifact that does not exist" do
      get "/admin/agents/artifacts/#{Blog::Constants::INTEGER_MAX}"

      expect(last_response.status).to eq(404)
    end
  end

  describe "an old version" do
    let(:found) { artifact(body: "First body") }

    before do
      agents(:update_artifact, found.id, { title: found.title, type: "plan", tags: "", body: "Second body" })
      get "/admin/agents/artifacts/#{found.id}", version: 1
    end

    it "shows the old body under a banner", :aggregate_failures do
      expect(page).to have_css(".markdown-body", text: "First body")
      expect(page).to have_css(".post-banner", text: "You are reading v1 of 2")
    end

    it "restores it with a plain form" do
      expect(page.find(".post-banner form")["action"]).to eq("/admin/agents/artifacts/#{found.id}/versions/1/restore")
    end

    it "restores it as a new version with the old body", :aggregate_failures do
      admin_post "/admin/agents/artifacts/#{found.id}/versions/1/restore"

      expect(last_response.location).to end_with("/admin/agents/artifacts/#{found.id}")
      expect(versions(found.id).map(&:number)).to eq([1, 2, 3])
      expect(Agents::Slice["repos.artifact_queries"].version(found.id, 3).body).to eq("First body")
    end
  end

  describe "editing" do
    let(:found) { artifact }

    def save(**fields)
      fields = { title: found.title, type: "plan", tags: "", body: "Add an index", **fields }
      admin_post "/admin/agents/artifacts/#{found.id}", artifact: fields
    end

    it "fills the form with the latest body" do
      get "/admin/agents/artifacts/#{found.id}/edit"

      expect(page).to have_field("artifact[body]", with: "Add an index")
    end

    it "adds a version with its note on a body change", :aggregate_failures do
      save(body: "Add two indexes", note: "Split the index")

      expect(last_response.location).to end_with("/admin/agents/artifacts/#{found.id}")
      expect(versions(found.id).map { [it.number, it.note, it.agent] })
        .to eq([[1, nil, "claude-code"], [2, "Split the index", nil]])
    end

    it "adds no version when only the title changes, and clears the agent's mark on it", :aggregate_failures do
      save(title: "Index plan")

      expect(versions(found.id).size).to eq(1)
      expect(reload(found.id)).to have_attributes(title: "Index plan", title_agent: nil)
    end

    it "refuses a note over the cap" do
      save(body: "Changed", note: "x" * 201)

      expect(page).to have_css("#artifact-note-error", text: "200 characters")
    end
  end

  describe "record links" do
    let(:found) { artifact }
    let(:task) { create(:task, title: "Index the activities table") }

    it "shows the artifact's links" do
      Links::Slice["operations.link_records"].call("artifact", found.id, { other_kind: "task", other_id: task.id })
      get "/admin/agents/artifacts/#{found.id}"

      expect(page.find(".record-links")).to have_link("Index the activities table", href: "/admin/tasks/#{task.id}")
    end

    it "links and unlinks a record with plain forms", :aggregate_failures do
      admin_post "/admin/agents/artifacts/#{found.id}/records", record: { other_kind: "task", other_id: task.id.to_s }
      expect(Links::Slice["repos.record_link_queries"].for_record("artifact", found.id).keys).to eq(%w[task])

      admin_post "/admin/agents/artifacts/#{found.id}/records/task/#{task.id}/delete"
      expect(Links::Slice["repos.record_link_queries"].for_record("artifact", found.id)).to be_empty
    end

    it "links back from the task to the artifact page" do
      Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "artifact", other_id: found.id })

      link = Links::Slice["repos.record_link_queries"].for_record("task", task.id).fetch("artifact").first
      expect(link.url).to eq("/admin/agents/artifacts/#{found.id}")
    end
  end

  it "deletes the artifact with every version", :aggregate_failures do
    found = artifact
    admin_post "/admin/agents/artifacts/#{found.id}/delete"

    expect(last_response.location).to end_with("/admin/agents/artifacts")
    expect(reload(found.id)).to be_nil
  end

  describe "the session drawer" do
    let(:session_id) { agents(:start_session, { title: "Index", **author, task_ids: [] }).first }

    before { artifact(session_id:) }

    it "links each artifact a session wrote to its version" do
      get "/admin/agents/sessions", session: session_id
      found = reload(Agents::Slice["relations.artifacts"].dataset.max(:id))

      expect(page.find_by_id("agent-session"))
        .to have_link(href: "/admin/agents/artifacts/#{found.id}?version=1")
    end
  end
end
