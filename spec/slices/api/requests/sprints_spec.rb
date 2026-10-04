# frozen_string_literal: true

RSpec.describe "API sprints", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/sprints#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def current = call_api(:get, "/current")

  def drop(id) = call_api(:delete, "/#{id}")

  def list(**window) = call_api(:get, "", window)

  def plan(fields) = call_api(:post, "", JSON.generate(fields))

  def sprints = Tasks::Slice["repos.sprint_repo"]

  def status = last_response.status

  def today = Blog::TimeZone.today

  describe "GET /api/v1/sprints/current" do
    it "answers today's sprint with its tasks", :aggregate_failures do
      sprint = create(:sprint, sprint_date: today, carried_in: 2)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "today's work")

      expect(current.except("tasks")).to eq("id" => sprint.id, "date" => today.iso8601, "carried_in" => 2)
      expect(current.fetch("tasks").map { it.values_at("title", "sprint_on") }).to eq([["today's work", today.iso8601]])
    end

    it "starts today's sprint when there is none" do
      current

      expect([status, sprints.on(today)]).to match([200, have_attributes(sprint_date: today)])
    end

    it "answers a failure it did not expect with a 500" do
      failing = instance_double(Tasks::Operations::CurrentSprint, call: Dry::Monads::Failure(:unexpected))
      replace_component("tasks.operations.current_sprint", failing)

      expect([current, status]).to eq([{ "error" => "failed", "message" => "could not open today's sprint" }, 500])
    end
  end

  describe "GET /api/v1/sprints" do
    def dates(**window) = list(**window).fetch("sprints").map { it.fetch("date") }

    before { [today - 1, today, today + 1].each { create(:sprint, sprint_date: it) } }

    it "lists today's sprint and the planned ones when it names no window" do
      expect(dates).to eq([today, today + 1].map(&:iso8601))
    end

    it "leaves the start of the window open when it names no from" do
      expect(dates(to: today.iso8601)).to eq([today - 1, today].map(&:iso8601))
    end

    it "lists the sprints inside a window" do
      expect(dates(from: (today - 1).iso8601, to: today.iso8601)).to eq([today - 1, today].map(&:iso8601))
    end

    it "says the page is whole" do
      expect(list).to include("partial" => false)
    end

    it "pages the way list_sprints does", :aggregate_failures do
      lower_page_size(:mcp, to: 1)

      expect(list).to include("partial" => true, "next_page" => 2)
      expect(list(page: 2).fetch("sprints").map { it.fetch("date") }).to eq([(today + 1).iso8601])
    end

    it "refuses a window that runs backwards with a 422" do
      refusal = { "error" => "invalid", "message" => "from comes after to",
                  "errors" => { "from" => ["from comes after to"], "to" => ["from comes after to"] } }

      expect([list(from: today.iso8601, to: (today - 1).iso8601), status]).to eq([refusal, 422])
    end

    it "refuses a day it cannot read with a 422" do
      expect([list(from: "next week").fetch("message"), status])
        .to eq(["give from and to as days, such as 2026-01-01", 422])
    end

    it "refuses a page before the first with a 422" do
      expect([list(page: 0).fetch("errors").keys, status]).to eq([%w[page], 422])
    end

    it "refuses a page that is not a number with a 422" do
      expect([list(page: "two").fetch("errors").keys, status]).to eq([%w[page], 422])
    end
  end

  describe "POST /api/v1/sprints" do
    it "plans the sprint for a later day" do
      expect([plan(sprint_on: (today + 2).iso8601).except("id"), status])
        .to eq([{ "date" => (today + 2).iso8601, "carried_in" => 0 }, 201])
    end

    it "refuses a day already planned with a 422" do
      create(:sprint, sprint_date: today + 2)
      taken = "a sprint already exists for #{(today + 2).iso8601}"

      expect([plan(sprint_on: (today + 2).iso8601), status])
        .to eq([{ "error" => "invalid", "message" => taken, "errors" => { "sprint_on" => [taken] } }, 422])
    end

    it "refuses today and saves nothing" do
      plan(sprint_on: today.iso8601)

      expect([status, sprints.on(today)]).to eq([422, nil])
    end

    it "refuses a day it cannot read" do
      expect([plan(sprint_on: "next week").fetch("message"), status])
        .to eq(["pick a day first, such as 2026-01-01", 422])
    end

    it "refuses a request with no day" do
      expect([plan({}).fetch("errors"), status]).to eq([{ "sprint_on" => ["sprint_on is missing"] }, 422])
    end

    it "refuses a body that is not JSON with a 400" do
      expect([call_api(:post, "", "{nope").fetch("error"), status]).to eq(["invalid_json", 400])
    end
  end

  describe "DELETE /api/v1/sprints/:id" do
    it "drops a planned sprint and sends its tasks back to next", :aggregate_failures do
      sprint = create(:sprint, sprint_date: today + 1)
      task = create(:task, :in_sprint, sprint_id: sprint.id)

      expect(drop(sprint.id)).to eq("id" => sprint.id, "date" => (today + 1).iso8601, "carried_in" => 0,
                                    "dropped" => true)
      expect(Tasks::Slice["queries.task_by_id"].call(task.id)).to have_attributes(list: "next", sprint: nil)
    end

    it "refuses a sprint that has started with a 422" do
      sprint = create(:sprint, sprint_date: today)

      expect([drop(sprint.id).fetch("message"), status]).to eq(["that sprint has already started", 422])
    end

    it "answers an unknown ID with a 404" do
      expect([drop(404), status]).to eq([{ "error" => "not_found", "message" => "no sprint has the ID 404" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([drop("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end

  describe "the MCP tools" do
    it "read the current sprint as read_current_sprint does" do
      create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id)

      expect(current).to eq(mcp_answer("read_current_sprint"))
    end

    it "list as list_sprints does" do
      [today, today + 1].each { create(:sprint, sprint_date: it) }

      expect(list(from: today.iso8601)).to eq(mcp_answer("list_sprints", from: today.iso8601))
    end

    it "plan as plan_sprint does" do
      planned = plan(sprint_on: (today + 1).iso8601)

      expect(mcp_answer("plan_sprint", sprint_on: (today + 2).iso8601).except("id", "date"))
        .to eq(planned.except("id", "date"))
    end

    it "drop as drop_sprint does" do
      ids = [create(:sprint, sprint_date: today + 1).id, create(:sprint, sprint_date: today + 2).id]
      dropped = drop(ids.first)

      expect(mcp_answer("drop_sprint", id: ids.last).except("id", "date")).to eq(dropped.except("id", "date"))
    end

    it "refuse with the message the endpoint gives" do
      sprint = create(:sprint, sprint_date: today)
      refused = drop(sprint.id)

      expect(mcp_text("drop_sprint", id: sprint.id)).to eq(refused.fetch("message"))
    end
  end
end
