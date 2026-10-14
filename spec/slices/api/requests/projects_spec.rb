# frozen_string_literal: true

RSpec.describe "API projects", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/projects#{path}", body && JSON.generate(body), headers)
    JSON.parse(last_response.body)
  end

  def project_queries = Projects::Slice["repos.project_queries"]

  def status = last_response.status

  def today = Blog::TimeZone.today

  describe "GET /api/v1/projects" do
    it "lists live projects, then archived ones, with a 200" do
      create(:project, :archived, name: "old")
      create(:project, :private, name: "live")

      expect([call_api(:get, "").fetch("projects").map { it.fetch("name") }, status]).to eq([%w[live old], 200])
    end

    it "answers the same JSON as list_projects" do
      create(:project, tags: %w[ruby])

      expect(call_api(:get, "")).to eq(mcp_answer("list_projects"))
    end
  end

  describe "POST /api/v1/projects" do
    it "adds an active project with a 201", :aggregate_failures do
      found = call_api(:post, "", { name: "blog", visibility: "private", tags: %w[ruby] })

      expect([found.values_at("name", "visibility", "status", "tags"), status])
        .to eq([["blog", "private", "active", %w[ruby]], 201])
      expect(project_queries.by_id(found.fetch("id")).board_published).to be(false)
    end

    it "refuses a project with no visibility with a 422" do
      expect([call_api(:post, "", { name: "blog" }).fetch("errors"), status])
        .to eq([{ "visibility" => ["pick public or private"] }, 422])
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "keeps every field the change leaves out" do
      project = create(:project, name: "blog", tags: %w[ruby])

      expect(call_api(:patch, "/#{project.id}", { tagline: "new" }))
        .to include("name" => "blog", "tagline" => "new", "tags" => %w[ruby])
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:patch, "/999999", { name: "ghost" }).fetch("message"), status])
        .to eq(["no project has the ID 999999", 404])
    end
  end

  describe "POST /api/v1/projects/:id/archive" do
    it "archives the project as of today" do
      project = create(:project)

      expect([call_api(:post, "/#{project.id}/archive").values_at("status", "archived_on"), status])
        .to eq([["archived", today.iso8601], 200])
    end

    it "refuses a project whose start month has not come with a 422" do
      project = create(:project, started_on: today + 40)

      expect([call_api(:post, "/#{project.id}/archive").fetch("message"), status])
        .to eq(["not archived: its start month has not come yet", 422])
    end

    it "answers an unknown ID with a 404" do
      call_api(:post, "/999999/archive")

      expect(status).to eq(404)
    end
  end

  describe "POST /api/v1/projects/:id/restore" do
    it "restores an archived project as active" do
      project = create(:project, :archived)

      expect([call_api(:post, "/#{project.id}/restore").values_at("status", "archived_on"), status])
        .to eq([["active", nil], 200])
    end

    it "answers a project that is not archived with a 404" do
      project = create(:project)

      expect([call_api(:post, "/#{project.id}/restore").fetch("message"), status])
        .to eq(["no archived project has the ID #{project.id}", 404])
    end
  end
end
