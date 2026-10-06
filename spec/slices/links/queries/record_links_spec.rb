# frozen_string_literal: true

RSpec.describe Links::Queries::RecordLinks do
  let(:decision) { create(:decision, title: "Pick a host") }

  def link(kind, id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind: "decision", other_id: decision.id }).value!
  end

  def links = Links::Slice["queries.record_links"].call("decision", decision.id)

  def only(kind) = links.fetch(kind).first

  it "groups links by kind in the order of the kinds" do
    %w[commit task work_entry post].each { link(it, linkable_record(it).id) }

    expect(links.keys).to eq(%w[task post commit work_entry])
  end

  it "reads an id that comes as text, as a route sends it" do
    post = linkable_record("post")
    link("post", post.id)

    expect(Links::Slice["queries.record_links"].call("decision", decision.id.to_s).keys).to eq(["post"])
  end

  it "lists nothing for a record with no links" do
    expect(links).to eq({})
  end

  it "lists nothing for a kind it does not know" do
    expect(Links::Slice["queries.record_links"].call("person", 1)).to eq({})
  end

  describe "what each link carries" do
    it "names a task by its title and links to its page" do
      task = create(:task, title: "Move the server")
      link("task", task.id)

      expect(only("task")).to have_attributes(id: task.id, title: "Move the server", url: "/admin/tasks/#{task.id}")
    end

    it "names a post by its title and links to its editor" do
      post = create(:post, title: "On hosting")
      link("post", post.id)

      expect(only("post")).to have_attributes(title: "On hosting", url: "/admin/posts/#{post.id}/edit")
    end

    it "names a social post by its first part and links to its editor" do
      social_post = linkable_record("social_post", "Moving day")
      link("social_post", social_post.id)

      expect(only("social_post")).to have_attributes(title: "Moving day", url: "/admin/social?edit=#{social_post.id}")
    end

    it "names a journal entry by its first line and links to its day" do
      entry = create(:journal_entry, body: "Packed the rack\nThen slept", entry_date: Date.new(2026, 9, 30))
      link("journal_entry", entry.id)

      expect(only("journal_entry")).to have_attributes(
        title: "Packed the rack", day: Date.new(2026, 9, 30), url: "/admin/journal?to=2026-09-30#day-2026-09-30",
      )
    end

    it "names a commit by its first line and links to its page" do
      commit = create(:commit, message: "Add the host\n\nLonger body")
      link("commit", commit.id)

      expect(only("commit")).to have_attributes(title: "Add the host", url: "/admin/commits/#{commit.id}")
    end

    it "names a project by its name and links to its editor" do
      project = create(:project, name: "homelab")
      link("project", project.id)

      expect(only("project")).to have_attributes(title: "homelab", url: "/admin/projects/#{project.id}/edit")
    end

    it "names a work entry by its role and org and links to the work list" do
      entry = create(:work_entry, org: "Acme", role: "Engineer")
      link("work_entry", entry.id)

      expect(only("work_entry")).to have_attributes(title: "Engineer, Acme", url: "/admin/projects?filter=work")
    end

    it "names a decision by its title and links to its page" do
      other = create(:decision, title: "Pick a rack")
      link("decision", other.id)

      expect(only("decision")).to have_attributes(id: other.id, title: "Pick a rack",
                                                  url: "/admin/decisions/#{other.id}")
    end

    it "cuts a long title" do
      link("journal_entry", create(:journal_entry, body: "word " * 100).id)

      expect(only("journal_entry").title.length).to eq(Links::Queries::LinkableRecords::TITLE_LIMIT)
    end
  end
end
