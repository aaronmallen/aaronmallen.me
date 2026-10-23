# frozen_string_literal: true

RSpec.describe "Admin agent tags", type: :request do
  let(:author) { { agent: "claude-code", model: "claude-opus-5-5" } }
  let(:page) { Capybara.string(last_response.body) }
  let(:project) { create(:project, name: "blog", key: "BLOG", repo: "aaronmallen/blog") }

  def agents(name, *, **) = Agents::Slice["operations.#{name}"].call(*, **).value!

  def drawer = page.find_by_id("agent-session")

  def link(id)
    Links::Slice["operations.link_records"].call("artifact", id, { other_kind: "project", other_id: project.id })
  end

  def session_id
    @session_id ||= agents(:start_session, { title: "Spike", repo: project.repo, **author, task_ids: [] }).first
  end

  def session_tags = Agents::Slice["repos.agent_session_queries"].by_id(session_id).tags

  before { sign_in_to_admin }

  describe "a session" do
    let(:back) { "/admin/agents/sessions?session=#{session_id}" }

    it "takes its project's own tag from the drawer", :aggregate_failures do
      admin_post "/admin/agents/sessions/#{session_id}/tags", tag: "perf", return_to: back

      expect(last_response.location).to end_with(back)
      expect(session_tags.map { [it.name, it.scope, it.project_id] }).to eq([["perf", "project", project.id]])
    end

    it "shows its tags in the drawer, linked to the project's tag page" do
      agents(:tag_session, session_id, "perf")
      get back

      expect(drawer).to have_link("#perf", href: "/admin/projects/BLOG/tags/perf")
    end

    it "takes a tag off from the drawer" do
      agents(:tag_session, session_id, "perf")
      admin_post "/admin/agents/sessions/#{session_id}/tags/delete", tag: "perf", return_to: back

      expect(session_tags).to be_empty
    end
  end

  describe "a memory file" do
    let(:file) do
      agents(:create_memory_file, { path: "notes", description: "Notes", scope: "project", project_id: project.id,
                                    **author })
    end

    def file_tags = Agents::Slice["repos.memory_file_queries"].by_id(file.id).tags

    it "takes its project's own tag from its page" do
      admin_post "/admin/agents/memories/#{file.id}/tags", tag: "perf"

      expect(file_tags.map { [it.name, it.scope, it.project_id] }).to eq([["perf", "project", project.id]])
    end

    it "shows its tags on its page, linked to the project's tag page" do
      agents(:tag_memory_file, file.id, "perf")
      get "/admin/agents/memories/#{file.id}"

      expect(page).to have_link("#perf", href: "/admin/projects/BLOG/tags/perf")
    end

    it "takes a tag off from its page" do
      agents(:tag_memory_file, file.id, "perf")
      admin_post "/admin/agents/memories/#{file.id}/tags/delete", tag: "perf"

      expect(file_tags).to be_empty
    end
  end

  describe "an artifact linked to a project" do
    let(:artifact) { agents(:create_artifact, { title: "Plan", type: "plan", tags: "", body: "Steps", **author }) }

    before { link(artifact.id) }

    it "offers its project's tags in the editor" do
      create(:tag, name: "perf", scope: "project", project_id: project.id)
      get "/admin/agents/artifacts/#{artifact.id}/edit"

      expect(JSON.parse(page.find("#artifact-form .tag-pick", visible: :all)["data-tag-field"]).map { it["name"] })
        .to eq(%w[perf])
    end

    it "saves the editor's tags as its project's own tags" do
      fields = { title: "Plan", type: "plan", tags: "perf", body: "Steps" }
      admin_post "/admin/agents/artifacts/#{artifact.id}", artifact: fields

      expect(Agents::Slice["repos.artifact_queries"].by_id(artifact.id).tags.map(&:project_id)).to eq([project.id])
    end
  end

  describe "the project tag page" do
    before do
      agents(:tag_session, session_id, "perf")
      fields = { path: "notes", description: "Notes", scope: "project", project_id: project.id, **author }
      file = agents(:create_memory_file, fields)
      agents(:tag_memory_file, file.id, "perf")
      artifact = agents(:create_artifact, { title: "Plan", type: "plan", tags: "", body: "Steps", **author })
      link(artifact.id)
      agents(:update_artifact, artifact.id, { title: "Plan", type: "plan", tags: "perf", body: "Steps", **author })
      get "/admin/projects/BLOG/tags/perf"
    end

    def titles(kind)
      page.find(".card", text: Admin::Slice["i18n"].t(["ui.views.tags.show.kinds", kind].join(".")))
          .all(".li-title").map(&:text)
    end

    it "lists the sessions, memory files and artifacts that carry it", :aggregate_failures do
      expect(titles(:agent_sessions)).to eq(["Spike"])
      expect(titles(:memory_files)).to eq(["notes.md"])
      expect(titles(:artifacts)).to eq(["Plan"])
    end
  end
end
