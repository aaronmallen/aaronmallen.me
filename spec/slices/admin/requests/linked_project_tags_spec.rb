# frozen_string_literal: true

RSpec.describe "Admin linked project tags", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:blog) { create(:project, name: "blog", key: "BLOG") }
  let(:pod) { create(:project, name: "pod", key: "POD") }
  let(:tags) { Tags::Slice["relations.tags"] }

  def held(join, owner_key, id)
    tags.dataset.db[join].where(owner_key => id).join(:tags, id: :tag_id)
        .order(:name, :project_id).select_map([Sequel[:tags][:name], Sequel[:tags][:scope], Sequel[:tags][:project_id]])
  end

  def link(kind, id, project = blog)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind: "project", other_id: project.id }).value!
  end

  def names(json) = JSON.parse(json).map { it["name"] }

  def offered(field)
    names(page.find("input[name='#{field}']", visible: :all).sibling(".tag-pick", visible: :all)["data-tag-field"])
  end

  def project_tag(name, project = blog) = create(:tag, name:, scope: "project", project_id: project.id)

  def suggested = names(page.find("[data-menu-suggest]", visible: :all)["data-menu-suggest"])

  def unlink(kind, id, project = blog)
    Links::Slice["operations.unlink_records"].call(kind, id, "project", project.id).value!
  end

  before { sign_in_to_admin }

  describe "a decision linked to a project" do
    let(:decision) { create(:decision, title: "Pick a host", tags: %w[old]) }

    before { link("decision", decision.id) }

    def save(tags)
      decision_params = { title: decision.title, problem: decision.problem, tags:, note: "" }
      admin_post("/admin/decisions/#{decision.id}", decision: decision_params)
    end

    it "takes the project's tag for a name the project holds and makes no private one", :aggregate_failures do
      project_tag("bug")
      save("bug")

      expect(held(:decision_tags, :decision_id, decision.id)).to eq([["bug", "project", blog.id]])
      expect(tags.where(scope: "private", name: "bug").count).to eq(0)
    end

    it "makes a new name in the project" do
      save("hosting")

      expect(held(:decision_tags, :decision_id, decision.id)).to eq([["hosting", "project", blog.id]])
    end

    it "makes a new name in each project it links to" do
      link("decision", decision.id, pod)
      save("hosting")

      expect(held(:decision_tags, :decision_id, decision.id))
        .to eq([["hosting", "project", blog.id], ["hosting", "project", pod.id]])
    end

    it "uses only the projects that hold a name when one does" do
      link("decision", decision.id, pod)
      project_tag("bug", pod)
      save("bug")

      expect(held(:decision_tags, :decision_id, decision.id)).to eq([["bug", "project", pod.id]])
    end

    it "adds a project tag from the tag menu" do
      admin_post("/admin/decisions/#{decision.id}/tags", tag: "bug")

      expect(held(:decision_tags, :decision_id,
                  decision.id)).to eq([["bug", "project", blog.id], %w[old private] + [nil]])
    end

    it "takes a project tag off from the tag menu" do
      save("bug")
      admin_post("/admin/decisions/#{decision.id}/tags/delete", tag: "bug")

      expect(held(:decision_tags, :decision_id, decision.id)).to be_empty
    end

    it "offers the tags of every linked project in the editor" do
      link("decision", decision.id, pod)
      [project_tag("bug"), project_tag("infra", pod), create(:tag, :private, name: "home")]
      get "/admin/decisions/#{decision.id}/edit"

      expect(offered("decision[tags]")).to eq(%w[bug infra])
    end

    it "offers the project's tags in the menu" do
      project_tag("bug")
      create(:tag, :private, name: "home")
      get "/admin/decisions/#{decision.id}/menu"

      expect(suggested).to eq(%w[bug])
    end

    it "links a project tag in the list to the project's tag page" do
      save("bug")
      get "/admin/decisions"

      expect(page).to have_link("#bug", href: "/admin/projects/BLOG/tags/bug")
    end

    it "drops the project's tags when the link goes and keeps the other project's", :aggregate_failures do
      link("decision", decision.id, pod)
      save("bug")
      unlink("decision", decision.id)

      expect(held(:decision_tags, :decision_id, decision.id)).to eq([["bug", "project", pod.id]])
      expect(tags.where(scope: "project", project_id: blog.id, name: "bug").count).to eq(1)
    end
  end

  it "keeps private tags on a decision with no project link" do
    decision = create(:decision)
    admin_post("/admin/decisions/#{decision.id}/tags", tag: "home")

    expect(held(:decision_tags, :decision_id, decision.id)).to eq([["home", "private", nil]])
  end

  describe "a journal entry linked to a project" do
    let(:entry) { create(:journal_entry) }

    before { link("journal_entry", entry.id) }

    it "takes a project tag from the tag menu" do
      admin_post("/admin/journal/#{entry.id}/tags", tag: "bug")

      expect(held(:journal_entry_tags, :journal_entry_id, entry.id)).to eq([["bug", "project", blog.id]])
    end

    it "offers the project's tags to its edit form" do
      project_tag("bug")
      create(:tag, :private, name: "home")
      get "/admin/tags/private/choices", record: "journal_entry", id: entry.id

      expect(JSON.parse(last_response.body).fetch("tags").map { it["name"] }).to eq(%w[bug])
    end

    it "points its edit form at those choices" do
      get "/admin/journal"

      expect(page.find(".journal-entry")["data-journal-tag-choices"])
        .to eq("/admin/tags/private/choices?record=journal_entry&id=#{entry.id}")
    end

    it "drops the project's tags when the link goes" do
      admin_post("/admin/journal/#{entry.id}/tags", tag: "bug")
      unlink("journal_entry", entry.id)

      expect(held(:journal_entry_tags, :journal_entry_id, entry.id)).to be_empty
    end
  end

  it "offers private tags to a journal entry with no project link" do
    create(:tag, :private, name: "home")
    get "/admin/tags/private/choices", record: "journal_entry", id: create(:journal_entry).id

    expect(JSON.parse(last_response.body).fetch("tags").map { it["name"] }).to eq(%w[home])
  end

  describe "a note linked to a project" do
    let(:note) { create(:note) }

    before { link("note", note.id) }

    it "takes a project tag" do
      admin_post("/admin/notes/#{note.id}/tags", tag: "bug")

      expect(held(:note_tags, :note_id, note.id)).to eq([["bug", "project", blog.id]])
    end

    it "drops the project's tags when the link goes" do
      admin_post("/admin/notes/#{note.id}/tags", tag: "bug")
      unlink("note", note.id)

      expect(held(:note_tags, :note_id, note.id)).to be_empty
    end
  end

  describe "a mail thread linked to a project" do
    let(:thread) { create(:message) }

    before { link("mail_thread", thread.id) }

    it "takes a project tag" do
      admin_post("/admin/mail/bulk", "ids[]": thread.id, act: "tag", tag: "bug")

      expect(held(:mail_thread_tags, :mail_thread_id, thread.id)).to eq([["bug", "project", blog.id]])
    end

    it "offers the project's tags in the menu" do
      project_tag("bug")
      create(:tag, :private, name: "home")
      get "/admin/mail/#{thread.id}/menu"

      expect(suggested).to eq(%w[bug])
    end
  end

  describe "a post linked to a project" do
    let(:post_record) { create(:post, :published, title: "Fixing the feed", tags: %w[ruby]) }

    before { link("post", post_record.id) }

    def save(**fields)
      form = post_record.then { Posts::Slice["repos.post_queries"].by_id(it.id).form }
      admin_post("/admin/posts/#{post_record.id}", post: form.merge(edit_note: "", **fields))
    end

    it "keeps its public tags beside the project's tags" do
      save(project_tags: "bug")

      expect(held(:post_tags, :post_id, post_record.id)).to eq([["bug", "project", blog.id], %w[ruby public] + [nil]])
    end

    it "keeps its project tags when only the public tags change" do
      save(project_tags: "bug")
      save(tags: "ruby, hanami")

      expect(held(:post_tags, :post_id, post_record.id).map(&:first)).to eq(%w[bug hanami ruby])
    end

    it "offers a project tags field with the project's tags" do
      project_tag("bug")
      create(:tag, :private, name: "home")
      get "/admin/posts/#{post_record.id}/edit"

      expect(offered("post[project_tags]")).to eq(%w[bug])
    end

    it "shows no project tags field on a post with no project link" do
      get "/admin/posts/#{create(:post).id}/edit"

      expect(page).to have_no_field("post[project_tags]", visible: :all)
    end

    it "leaves the project's tags off the public post and tag page", :aggregate_failures do
      save(project_tags: "bug")
      get "/posts/#{post_record.slug}"
      expect(last_response.body).not_to include("bug")

      get "/tags/bug"
      expect(last_response.status).to eq(404)
    end
  end

  describe "the project tag page" do
    before do
      bug = project_tag("bug")
      {
        decision_tags: [:decision_id, create(:decision, title: "Drop the feed")],
        note_tags: [:note_id, create(:note, title: "Feed notes")],
        journal_entry_tags: [:journal_entry_id, create(:journal_entry, body: "Chased the feed bug")],
        mail_thread_tags: [:mail_thread_id, create(:message, subject: "Feed broke")],
        post_tags: [:post_id, create(:post, title: "Fixing the feed")],
      }.each do |join, (owner_key, record)|
        tags.dataset.db[join].insert(owner_key => record.id, tag_id: bug.id, tag_scope: "project")
      end
    end

    it "lists decisions, notes, journal entries, mail and posts" do
      get "/admin/projects/BLOG/tags/bug"

      expect(page.all(".li-title").map(&:text))
        .to contain_exactly("Drop the feed", "Feed notes", "Chased the feed bug", "Feed broke", "Fixing the feed")
    end
  end
end
