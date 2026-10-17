# frozen_string_literal: true

RSpec.describe "API projects", type: :request do
  def project_queries = Projects::Slice["repos.project_queries"]

  describe "GET /api/v1/projects" do
    it "lists live projects, then archived ones, with a 200" do
      create(:project, :archived, name: "old")
      create(:project, :private, name: "live")

      names = call_api(:get, "/projects").fetch("projects").map { it.fetch("name") }

      expect([names, status]).to eq([%w[live old], 200])
    end

    it "answers the same JSON as list_projects" do
      create(:project, tags: %w[ruby])

      expect(call_api(:get, "/projects")).to eq(mcp_answer("list_projects"))
    end
  end

  describe "POST /api/v1/projects" do
    it "adds an active project with a 201", :aggregate_failures do
      found = call_api(:post, "/projects", { name: "blog", visibility: "private", tags: %w[ruby] })

      expect([found.values_at("name", "visibility", "status", "tags"), status])
        .to eq([["blog", "private", "active", %w[ruby]], 201])
      expect(project_queries.by_id(found.fetch("id")).board_published).to be(false)
    end

    it "fills in the new project's stars", :commits do
      connect_github_token
      stub_github_repo("aaronmallen/blog", stars: 42, release: "v1.0.0")
      found = call_api(:post, "/projects", { name: "blog", repo: "aaronmallen/blog", visibility: "private" })
      Projects::Jobs::RefreshProject.drain

      expect(project_queries.by_id(found.fetch("id")).stars).to eq(42)
    end

    it "refuses a project with no visibility with a 422" do
      expect([call_api(:post, "/projects", { name: "blog" }).fetch("errors"), status])
        .to eq([{ "visibility" => ["pick public or private"] }, 422])
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "keeps every field the change leaves out" do
      project = create(:project, name: "blog", tags: %w[ruby])

      expect(call_api(:patch, "/projects/#{project.id}", { tagline: "new" }))
        .to include("name" => "blog", "tagline" => "new", "tags" => %w[ruby])
    end
  end

  describe "POST /api/v1/projects/:id/archive" do
    it "archives the project as of today" do
      project = create(:project)

      expect([call_api(:post, "/projects/#{project.id}/archive").values_at("status", "archived_on"), status])
        .to eq([["archived", today.iso8601], 200])
    end

    it "refuses a project whose start month has not come with a 422" do
      project = create(:project, started_on: today + 40)

      expect([call_api(:post, "/projects/#{project.id}/archive").fetch("message"), status])
        .to eq(["not archived: its start month has not come yet", 422])
    end

    it "refuses an archived project with a 422 and keeps its archive day", :aggregate_failures do
      project = create(:project, :archived, archived_on: today - 30)

      expect([call_api(:post, "/projects/#{project.id}/archive").fetch("message"), status])
        .to eq(["not archived: it is archived already", 422])
      expect(project_queries.by_id(project.id).archived_on).to eq(today - 30)
    end
  end

  describe "POST /api/v1/projects/:id/restore" do
    it "restores an archived project as active" do
      project = create(:project, :archived)

      expect([call_api(:post, "/projects/#{project.id}/restore").values_at("status", "archived_on"), status])
        .to eq([["active", nil], 200])
    end

    it "answers a project that is not archived with a 404" do
      project = create(:project)

      expect([call_api(:post, "/projects/#{project.id}/restore").fetch("message"), status])
        .to eq(["no archived project has the ID #{project.id}", 404])
    end
  end
end
