# frozen_string_literal: true

RSpec.describe "MCP project and work entry tools", type: :request do
  let(:project_repo) { Projects::Slice["repos.project_repo"] }
  let(:work_entry_repo) { Projects::Slice["repos.work_entry_repo"] }

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: Blog::SecretToken.generate, scope: "read write",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments)
    body = JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } })

    post "/mcp", body, { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
  end

  def content = JSON.parse(message)

  def error? = result.fetch("isError", false)

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
  end

  def message = result.fetch("content").first.fetch("text")

  def month(date) = date.strftime("%Y-%m")

  def result = JSON.parse(last_response.body).fetch("result")

  def stamps(record) = { "created_at" => record.created_at.utc.iso8601, "updated_at" => record.updated_at.utc.iso8601 }

  def today = Blog::TimeZone.today

  describe "list_projects" do
    def archived(name, position, on) = create(:project, :archived, name:, position:, archived_on: on, started_on: on)

    before do
      create(:project, name: "second", position: 2, tags: %w[ruby])
      create(:project, name: "first", position: 1, started_on: Date.new(2024, 6, 1))
      archived("older", 3, Date.new(2025, 1, 2))
      archived("newer", 4, Date.new(2025, 3, 4))
      call_tool("list_projects")
    end

    def listed = content.fetch("projects")

    def named(name) = listed.find { it.fetch("name") == name }

    it "lists live projects in order, then archived ones newest first" do
      expect(listed.map { it.fetch("name") }).to eq(%w[first second newer older])
    end

    it "gives a live project its start day and no archive day" do
      expect(named("first")).to include("started_on" => "2024-06-01", "archived_on" => nil, "status" => "active")
    end

    it "gives an archived project the day it was archived" do
      expect(named("newer")).to include("archived_on" => "2025-03-04", "status" => "archived")
    end

    it "gives each project its tags" do
      expect(named("second").fetch("tags")).to eq(%w[ruby])
    end
  end

  describe "list_work_entries" do
    before do
      create(:work_entry, org: "early", from_year: 2010, to_year: 2012, position: 1)
      create(:work_entry, org: "middle", from_year: 2014, to_year: 2018, position: 2)
      create(:work_entry, :current, org: "now", from_year: 2020, position: 3)
    end

    def orgs = content.fetch("work_entries").map { it.fetch("org") }

    it "lists the roles that overlap the range" do
      call_tool("list_work_entries", from: "2017-01-01", to: "2021-12-31")

      expect(orgs).to eq(%w[middle now])
    end

    it "counts a role still held as running to today" do
      call_tool("list_work_entries", from: "2030-01-01", to: "2030-12-31")

      expect(orgs).to eq(%w[now])
    end

    it "leaves out a role that ended before the range" do
      call_tool("list_work_entries", from: "2013-01-01", to: "2013-12-31")

      expect(orgs).to be_empty
    end

    it "marks a role still held as current" do
      call_tool("list_work_entries", from: "2020-01-01", to: "2020-12-31")

      expect(content.fetch("work_entries").first).to include("org" => "now", "to_year" => nil, "current" => true)
    end

    it "refuses a day it cannot read", :aggregate_failures do
      call_tool("list_work_entries", from: "last year", to: "2020-12-31")

      expect(error?).to be(true)
      expect(message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a from that comes after its to" do
      call_tool("list_work_entries", from: "2021-01-01", to: "2020-12-31")

      expect(message).to eq("from comes after to")
    end
  end

  describe "read_project" do
    it "answers every field list_projects gives, with its stamps and no links" do
      project = create(:project, :archived, name: "kept", tags: %w[ruby], started_on: Date.new(2024, 6, 1))
      call_tool("list_projects")
      listed = content.fetch("projects").first
      call_tool("read_project", id: project.id)

      expect(content).to eq(listed.merge(stamps(project), "record_links" => {}))
    end

    it "answers the records linked to the project, grouped by kind" do
      project = create(:project)
      task = create(:task)
      link("project", project.id, "task", task.id)
      call_tool("read_project", id: project.id)

      expect(content.fetch("record_links")).to match("task" => [include("id" => task.id)])
    end

    it "calls an unknown ID an error" do
      call_tool("read_project", id: 999_999)

      expect([error?, message]).to eq([true, "no project has the ID 999999"])
    end
  end

  describe "read_work_entry" do
    it "answers every field list_work_entries gives, with no links" do
      entry = create(:work_entry, :current, org: "now", from_year: 2020, blurb: nil)
      call_tool("list_work_entries", from: "2020-01-01", to: "2020-12-31")
      listed = content.fetch("work_entries").first
      call_tool("read_work_entry", id: entry.id)

      expect(content).to eq(listed.merge("record_links" => {}))
    end

    it "answers the records linked to the work entry, grouped by kind" do
      entry = create(:work_entry)
      project = create(:project)
      link("work_entry", entry.id, "project", project.id)
      call_tool("read_work_entry", id: entry.id)

      expect(content.fetch("record_links")).to match("project" => [include("id" => project.id)])
    end

    it "calls an unknown ID an error" do
      call_tool("read_work_entry", id: 999_999)

      expect([error?, message]).to eq([true, "no work entry has the ID 999999"])
    end
  end

  describe "save_project" do
    it "adds a project, active unless told otherwise", :aggregate_failures do
      call_tool("save_project", name: "fresh", repo: "aaronmallen/fresh", tags: %w[ruby cli])

      expect(content).to include("name" => "fresh", "status" => "active", "url" => "https://github.com/aaronmallen/fresh")
      expect(project_repo.by_id(content.fetch("id")).tags.map(&:name)).to contain_exactly("ruby", "cli")
    end

    it "keeps every field a change leaves out", :aggregate_failures do
      project = create(:project, tagline: "kept", featured: true, started_on: Date.new(2024, 6, 1), tags: %w[ruby])
      call_tool("save_project", id: project.id, name: "renamed")

      saved = project_repo.by_id(project.id)
      expect(saved).to have_attributes(name: "renamed", tagline: "kept", featured: true, started_on: project.started_on)
      expect(saved.tags.map(&:name)).to eq(%w[ruby])
    end

    it "clears a field given as an empty string" do
      project = create(:project, tagline: "gone soon")
      call_tool("save_project", id: project.id, tagline: "")

      expect(project_repo.by_id(project.id).tagline).to be_nil
    end

    it "keeps an archived project archived" do
      project = create(:project, :archived)
      call_tool("save_project", id: project.id, name: "still archived")

      expect(project_repo.by_id(project.id).status).to eq("archived")
    end

    it "refuses a repository another project tracks, with the reason the admin gives", :aggregate_failures do
      create(:project, repo: "aaronmallen/taken")
      call_tool("save_project", name: "copy", repo: "aaronmallen/taken")

      expect(error?).to be(true)
      expect(message).to eq("repo: another project already tracks this repository")
    end

    it "refuses a start month still to come" do
      call_tool("save_project", name: "later", started_on: month(today >> 2))

      expect(message).to eq("started_on: pick this month or one before it")
    end

    it "refuses a start month after the day the project was archived" do
      project = create(:project, :archived, archived_on: Date.new(2024, 1, 15), started_on: Date.new(2023, 1, 1))
      call_tool("save_project", id: project.id, started_on: "2024-03")

      expect(message).to eq("started_on: the start month falls after the day this project was archived")
    end

    it "refuses a project with no name, and saves nothing", :aggregate_failures do
      call_tool("save_project", repo: "aaronmallen/nameless")

      expect(message).to eq("name: add a name")
      expect(project_repo.live).to be_empty
    end

    it "refuses a name made only of Unicode spaces, and saves nothing", :aggregate_failures do
      call_tool("save_project", name: "\u2003\u3000")

      expect(message).to eq("name: add a name")
      expect(project_repo.live).to be_empty
    end

    it "keeps a name with Unicode spaces around real words as typed" do
      call_tool("save_project", name: "\u2003Pick a queue\u00a0")
      call_tool("read_project", id: content.fetch("id"))

      expect(content.fetch("name")).to eq("\u2003Pick a queue\u00a0")
    end

    it "refuses an ID no project has" do
      call_tool("save_project", id: 999_999, name: "ghost")

      expect(message).to eq("no project has the ID 999999")
    end
  end

  describe "move_project" do
    before do
      create(:project, name: "one", position: 1)
      create(:project, name: "two", position: 2)
    end

    def names = project_repo.live.map(&:name)

    it "moves a project a step up", :aggregate_failures do
      call_tool("move_project", id: project_repo.live.last.id, direction: "up")

      expect(content).to include("moved" => true)
      expect(names).to eq(%w[two one])
    end

    it "moves nothing past the top and says so", :aggregate_failures do
      call_tool("move_project", id: project_repo.live.first.id, direction: "up")

      expect(content).to include("moved" => false)
      expect(names).to eq(%w[one two])
    end

    it "refuses an ID no live project has" do
      call_tool("move_project", id: 999_999, direction: "down")

      expect(message).to eq("no live project has the ID 999999")
    end
  end

  describe "archive_project" do
    it "archives a project as of today", :aggregate_failures do
      project = create(:project, featured: true)
      call_tool("archive_project", id: project.id)

      expect(content).to include("status" => "archived", "archived_on" => today.iso8601)
      expect(project_repo.by_id(project.id)).to have_attributes(status: "archived", featured: false)
    end

    it "refuses a project whose start month has not come, as the admin does", :aggregate_failures do
      project = create(:project, started_on: today + 40)
      call_tool("archive_project", id: project.id)

      expect(message).to eq("not archived: its start month has not come yet")
      expect(project_repo.by_id(project.id).status).to eq("active")
    end

    it "refuses an ID no project has" do
      call_tool("archive_project", id: 999_999)

      expect(message).to eq("no project has the ID 999999")
    end
  end

  describe "restore_project" do
    it "restores an archived project as active", :aggregate_failures do
      project = create(:project, :archived)
      call_tool("restore_project", id: project.id)

      expect(content).to include("status" => "active")
      expect(project_repo.by_id(project.id).archived_on).to be_nil
    end

    it "refuses a project that is not archived" do
      project = create(:project)
      call_tool("restore_project", id: project.id)

      expect(message).to eq("no archived project has the ID #{project.id}")
    end
  end

  describe "add_work_entry" do
    it "adds a role", :aggregate_failures do
      call_tool("add_work_entry", org: "Acme", role: "Engineer", from_year: 2019)

      expect(content).to include("org" => "Acme", "role" => "Engineer", "from_year" => 2019, "current" => true)
      expect(work_entry_repo.all.map(&:org)).to eq(%w[Acme])
    end

    it "refuses an end year before the start, with the reason the admin gives", :aggregate_failures do
      call_tool("add_work_entry", org: "Acme", role: "Engineer", from_year: 2019, to_year: 2017)

      expect(message).to eq("to_year: the end year falls before the start year")
      expect(work_entry_repo.all).to be_empty
    end

    it "refuses a year that is not four digits" do
      call_tool("add_work_entry", org: "Acme", role: "Engineer", from_year: 19)

      expect(message).to eq("from_year: use a four digit year, as 2018")
    end

    it "refuses a blank organization" do
      call_tool("add_work_entry", org: " ", role: "Engineer", from_year: 2019)

      expect(message).to eq("org: name the organization")
    end
  end

  describe "delete_work_entry" do
    it "removes a role" do
      entry = create(:work_entry)
      call_tool("delete_work_entry", id: entry.id)

      expect(work_entry_repo.all).to be_empty
    end

    it "refuses an ID no role has" do
      call_tool("delete_work_entry", id: 999_999)

      expect(message).to eq("no role has the ID 999999")
    end
  end
end
