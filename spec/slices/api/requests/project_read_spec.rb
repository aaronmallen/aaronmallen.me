# frozen_string_literal: true

RSpec.describe "API reading a project", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def link(id, other_kind, other_id)
    Links::Slice["operations.link_records"].call("project", id, { other_kind:, other_id: }).value!
  end

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/projects/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def shown(project)
    {
      "id" => project.id, "name" => "blog", "tagline" => "my site", "status" => "archived", "featured" => true,
      "started_on" => "2024-06-01", "archived_on" => "2026-03-02", "tags" => %w[ruby], "repo" => "aaronmallen/blog",
      "url" => "https://aaronmallen.me", "og_image_url" => nil, "stars" => 12, "release" => "v2.0.0",
      "created_at" => project.created_at.utc.iso8601, "updated_at" => project.updated_at.utc.iso8601,
      "record_links" => {},
    }
  end

  def status = last_response.status

  def whole_project
    create(
      :project, :archived, :featured,
      name: "blog", tagline: "my site", repo: "aaronmallen/blog", url: "https://aaronmallen.me", stars: 12,
      release: "v2.0.0", started_on: Date.new(2024, 6, 1), archived_on: Date.new(2026, 3, 2), tags: %w[ruby],
    )
  end

  describe "GET /api/v1/projects/:id" do
    it "answers the project with its stamps" do
      project = whole_project

      expect([read(project.id), status]).to eq([shown(project), 200])
    end

    it "answers the records linked to the project, grouped by kind" do
      project = create(:project)
      task = create(:task, title: "Move the server")
      link(project.id, "task", task.id)

      expect(read(project.id).fetch("record_links"))
        .to match("task" => [include("kind" => "task", "id" => task.id, "title" => "Move the server")])
    end

    it "answers the same JSON as read_project" do
      project = create(:project, tags: %w[cli])
      link(project.id, "post", create(:post).id)

      expect(read(project.id)).to eq(mcp_answer("read_project", id: project.id))
    end

    it "answers an unknown ID with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no project has the ID 999999" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end
end
