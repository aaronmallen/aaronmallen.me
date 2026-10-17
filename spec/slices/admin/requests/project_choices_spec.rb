# frozen_string_literal: true

RSpec.describe "Admin project choices", type: :request do
  def choices = get("/admin/projects/choices", {}, { "HTTP_ACCEPT" => "application/json" })

  it "answers 401 when signed out" do
    choices

    expect(last_response.status).to eq(401)
  end

  describe "signed in" do
    before do
      sign_in_to_admin
      create(:project, name: "Site", key: "SITE")
      create(:project, name: "Podcast", key: "POD")
      create(:project, :archived, name: "Gone", key: "GONE")
      choices
    end

    it "lists the live projects by name", :aggregate_failures do
      expect(last_response.media_type).to eq("application/json")
      expect(JSON.parse(last_response.body)).to eq(
        "projects" => [{ "key" => "POD", "name" => "Podcast" }, { "key" => "SITE", "name" => "Site" }],
      )
    end

    it "forbids caching the list" do
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end
  end
end
