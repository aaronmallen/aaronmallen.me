# frozen_string_literal: true

RSpec.describe "API work entries", type: :request do
  def work_entry_queries = Projects::Slice["repos.work_entry_queries"]

  describe "GET /api/v1/work_entries" do
    def listed = call_api(:get, "/work_entries", { from: "2019-01-01", to: "2019-12-31" })

    it "lists the roles that overlap the range with a 200" do
      held = create(:work_entry, org: "Acme", from_year: 2018, to_year: 2020)
      create(:work_entry, from_year: 2022, to_year: 2023)

      expect([listed.fetch("work_entries").map { it.fetch("id") }, status]).to eq([[held.id], 200])
    end

    it "answers the same JSON as list_work_entries" do
      create(:work_entry, :current)

      expect(listed).to eq(mcp_answer("list_work_entries", from: "2019-01-01", to: "2019-12-31"))
    end

    it "refuses a from that comes after its to with a 422" do
      call_api(:get, "/work_entries", { from: "2020-01-01", to: "2019-01-01" })

      expect(status).to eq(422)
    end
  end

  describe "POST /api/v1/work_entries" do
    it "adds the role with a 201" do
      added = call_api(:post, "/work_entries", JSON.generate(org: "Acme", role: "Staff", from_year: 2018))

      expect([added.values_at("org", "role", "from_year", "current"),
              status]).to eq([["Acme", "Staff", 2018, true], 201])
    end

    it "refuses an end year before the start year with a 422" do
      call_api(:post, "/work_entries", JSON.generate(org: "Acme", role: "Staff", from_year: 2020, to_year: 2018))

      expect([JSON.parse(last_response.body).fetch("errors"), status])
        .to eq([{ "to_year" => ["the end year falls before the start year"] }, 422])
    end
  end

  describe "DELETE /api/v1/work_entries/:id" do
    it "removes the role for good", :aggregate_failures do
      entry = create(:work_entry)

      expect([call_api(:delete, "/work_entries/#{entry.id}").values_at("id", "deleted"),
              status]).to eq([[entry.id, true], 200])
      expect(work_entry_queries.by_id(entry.id)).to be_nil
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:delete, "/work_entries/999999").fetch("message"),
              status]).to eq(["no role has the ID 999999", 404])
    end
  end
end
