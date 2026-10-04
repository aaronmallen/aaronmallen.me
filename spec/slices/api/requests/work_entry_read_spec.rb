# frozen_string_literal: true

RSpec.describe "API reading a work entry", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def link(id, other_kind, other_id)
    Links::Slice["operations.link_records"].call("work_entry", id, { other_kind:, other_id: }).value!
  end

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/work_entries/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def shown(entry)
    {
      "id" => entry.id, "org" => "Acme", "role" => "Staff", "blurb" => "built things", "from_year" => 2018,
      "to_year" => 2021, "current" => false, "record_links" => {},
    }
  end

  def status = last_response.status

  describe "GET /api/v1/work_entries/:id" do
    it "answers the work entry" do
      entry = create(:work_entry, org: "Acme", role: "Staff", blurb: "built things", from_year: 2018, to_year: 2021)

      expect([read(entry.id), status]).to eq([shown(entry), 200])
    end

    it "calls a role with no last year current" do
      entry = create(:work_entry, :current)

      expect(read(entry.id)).to include("to_year" => nil, "current" => true)
    end

    it "answers the records linked to the work entry, grouped by kind" do
      entry = create(:work_entry)
      project = create(:project, name: "blog")
      link(entry.id, "project", project.id)

      expect(read(entry.id).fetch("record_links"))
        .to match("project" => [include("kind" => "project", "id" => project.id, "title" => "blog")])
    end

    it "answers the same JSON as read_work_entry" do
      entry = create(:work_entry)
      link(entry.id, "post", create(:post).id)

      expect(read(entry.id)).to eq(mcp_answer("read_work_entry", id: entry.id))
    end

    it "answers an unknown ID with a 404" do
      expect([read(404), status]).to eq([{ "error" => "not_found", "message" => "no work entry has the ID 404" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end
end
