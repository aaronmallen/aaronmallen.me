# frozen_string_literal: true

RSpec.describe "API linked project tags", type: :request do
  let(:blog) { create(:project, name: "blog", key: "BLOG") }
  let(:db) { Tags::Slice["relations.tags"].dataset.db }

  def held(join, owner_key, id)
    db[join].where(owner_key => id).join(:tags, id: :tag_id).order(:name)
            .select_map([Sequel[:tags][:name], Sequel[:tags][:scope], Sequel[:tags][:project_id]])
  end

  def link(kind, id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind: "project", other_id: blog.id }).value!
  end

  def mcp_scopes = %w[read write notes mail]

  it "tags a decision linked to a project with the project's tags" do
    decision = create(:decision)
    link("decision", decision.id)
    call_api(:post, "/decisions/#{decision.id}/tags", { tags: %w[bug] })

    expect(held(:decision_tags, :decision_id, decision.id)).to eq([["bug", "project", blog.id]])
  end

  it "tags a journal entry linked to a project with the project's tags" do
    entry = create(:journal_entry)
    link("journal_entry", entry.id)
    call_api(:patch, "/journal_entries/#{entry.id}", { tags: %w[bug] })

    expect(held(:journal_entry_tags, :journal_entry_id, entry.id)).to eq([["bug", "project", blog.id]])
  end

  it "tags a note linked to a project with the project's tags through the MCP" do
    note = create(:note)
    link("note", note.id)
    mcp_call("tag_note", id: note.id, tag: "bug")

    expect(held(:note_tags, :note_id, note.id)).to eq([["bug", "project", blog.id]])
  end

  it "tags a mail thread linked to a project with the project's tags through the MCP" do
    thread = create(:message)
    link("mail_thread", thread.id)
    mcp_call("tag_mail_threads", ids: [thread.id], tag: "bug")

    expect(held(:mail_thread_tags, :mail_thread_id, thread.id)).to eq([["bug", "project", blog.id]])
  end

  describe "a record tagged before its second project link" do
    let(:pod) { create(:project, name: "pod", key: "POD") }

    def link_both(kind, id)
      link(kind, id)
      yield
      Links::Slice["operations.link_records"].call(kind, id, { other_kind: "project", other_id: pod.id }).value!
      yield
    end

    def projects(join, owner_key, id) = held(join, owner_key, id).map(&:last)

    it "copies a decision's tags into the new project" do
      decision = create(:decision)
      link_both("decision", decision.id) { call_api(:post, "/decisions/#{decision.id}/tags", { tags: %w[bug] }) }

      expect(projects(:decision_tags, :decision_id, decision.id)).to contain_exactly(blog.id, pod.id)
    end

    it "copies a journal entry's tags into the new project" do
      entry = create(:journal_entry)
      link_both("journal_entry", entry.id) { call_api(:patch, "/journal_entries/#{entry.id}", { tags: %w[bug] }) }

      expect(projects(:journal_entry_tags, :journal_entry_id, entry.id)).to contain_exactly(blog.id, pod.id)
    end

    it "copies a note's tags into the new project" do
      note = create(:note)
      link_both("note", note.id) { mcp_call("tag_note", id: note.id, tag: "bug") }

      expect(projects(:note_tags, :note_id, note.id)).to contain_exactly(blog.id, pod.id)
    end

    it "copies a mail thread's tags into the new project" do
      thread = create(:message)
      link_both("mail_thread", thread.id) { mcp_call("tag_mail_threads", ids: [thread.id], tag: "bug") }

      expect(projects(:mail_thread_tags, :mail_thread_id, thread.id)).to contain_exactly(blog.id, pod.id)
    end
  end

  describe "a post linked to a project" do
    let(:post_record) { create(:post, tags: %w[ruby]) }

    before { link("post", post_record.id) }

    it "takes project tags beside its public tags", :aggregate_failures do
      answer = call_api(:patch, "/posts/#{post_record.id}", { project_tags: %w[bug] })

      expect(held(:post_tags, :post_id, post_record.id)).to eq([["bug", "project", blog.id], ["ruby", "public", nil]])
      expect(answer.fetch("tags")).to eq(%w[ruby])
    end

    it "reads its project tags apart from its public ones" do
      call_api(:patch, "/posts/#{post_record.id}", { project_tags: %w[bug] })

      expect(call_api(:get, "/posts/#{post_record.id}").values_at("tags", "project_tags")).to eq([%w[ruby], %w[bug]])
    end

    it "takes project tags through the MCP" do
      mcp_call("update_post", id: post_record.id, project_tags: %w[bug])

      expect(held(:post_tags, :post_id, post_record.id).map(&:first)).to eq(%w[bug ruby])
    end
  end

  describe "reading a project tag" do
    before do
      bug = create(:tag, name: "bug", scope: "project", project_id: blog.id)
      note = create(:note, title: "Feed notes")
      thread = create(:message, subject: "Feed broke")
      db[:note_tags].insert(note_id: note.id, tag_id: bug.id, tag_scope: "project")
      db[:mail_thread_tags].insert(mail_thread_id: thread.id, tag_id: bug.id, tag_scope: "project")
    end

    def read(token: api_token) = call_api(:get, "/tags/bug?project=BLOG", token:)

    it "lists its notes and mail threads", :aggregate_failures do
      answer = read

      expect(answer.dig("notes", "records").map { it.fetch("title") }).to eq(["Feed notes"])
      expect(answer.dig("messages", "records").map { it.fetch("subject") }).to eq(["Feed broke"])
      expect(answer.fetch("counts").values_at("notes", "messages")).to eq([1, 1])
    end

    it "leaves notes and mail out without their scopes" do
      expect(read(token: api_token(%w[read])).keys & %w[notes messages]).to be_empty
    end

    it "answers the same JSON as read_tag" do
      expect(trusted(mcp_answer("read_tag", name: "bug", project: "BLOG"))).to eq(read(token: api_token(mcp_scopes)))
    end
  end
end
