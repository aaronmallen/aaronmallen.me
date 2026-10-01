# frozen_string_literal: true

RSpec.describe "Admin palette tasks", type: :request do
  def fetch_tasks(headers = {}) = get("/admin/tasks/palette", {}, { "HTTP_ACCEPT" => "application/json", **headers })

  def json = JSON.parse(last_response.body)

  describe "signed in" do
    let!(:next_task) { create(:task, title: "Email the accountant") }
    let!(:someday_task) { create(:task, :someday, title: "Learn the cello") }

    before do
      create(:task, :done, title: "Filed already")
      sign_in_to_admin
      fetch_tasks
    end

    it "answers with JSON", :aggregate_failures do
      expect(last_response.status).to eq(200)
      expect(last_response.media_type).to eq("application/json")
    end

    it "lists each open task by id, title and list" do
      expect(json.fetch("tasks")).to contain_exactly(
        { "id" => next_task.id, "title" => "Email the accountant", "list" => "next" },
        { "id" => someday_task.id, "title" => "Learn the cello", "list" => "someday" },
      )
    end

    it "leaves out finished tasks" do
      expect(json.fetch("tasks").map { it.fetch("title") }).not_to include("Filed already")
    end

    it "keeps the answer out of every cache" do
      expect(last_response.headers["Cache-Control"]).to include("no-store")
    end
  end

  describe "signed out" do
    before do
      create(:task, title: "Email the accountant")
      fetch_tasks
    end

    it "answers 401" do
      expect(last_response.status).to eq(401)
    end

    it "lists no task" do
      expect(last_response.body).not_to include("Email the accountant")
    end

    it "keeps the route out of where sign-in sends me" do
      expect(last_request.env["rack.session"]["return_to"]).to be_nil
    end
  end

  describe "with an API token and no session" do
    before do
      create(:task, title: "Email the accountant")
      token = API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:token)
      fetch_tasks("HTTP_AUTHORIZATION" => "Bearer #{token}")
    end

    it "answers 401" do
      expect(last_response.status).to eq(401)
    end
  end
end
