# frozen_string_literal: true

RSpec.describe "API time report", type: :request do
  let(:site) { create(:project, name: "site") }
  let(:gem) { create(:project, name: "gem") }
  let(:range) { { from: "2026-03-02", to: "2026-03-08" } }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour, minute = 0) = Blog::TimeZone.local_time(2026, 3, day, hour, minute)

  def groups(**) = read(**).fetch("groups")

  def link(task, *projects)
    projects.each do |project|
      Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
    end
    task
  end

  def read(**params)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/time_report", params, headers
    JSON.parse(last_response.body)
  end

  def screen_rows(**params)
    sign_in_to_admin
    get "/admin/time", params
    Capybara.string(last_response.body).all(".time-row").map { it.find(".meter-count").text }
  end

  def status = last_response.status

  def worked(title, from, to, tags: [])
    task = create(:task, :done, title:, tags:, worked_seconds: (to - from).to_i)
    create(:work_session, task_id: task.id, started_at: from, ended_at: to)
    task
  end

  describe "grouped by project" do
    let!(:tasks) do
      {
        both: link(worked("Ship the shared work", at(2, 9), at(2, 10)), site, gem),
        alone: link(worked("Polish the site", at(3, 9), at(3, 9, 30)), site),
        loose: worked("Answer email", at(4, 9), at(4, 9, 15)),
      }
    end

    before { link(worked("Out of range", at(20, 9), at(20, 10)), site) }

    it "answers the range, the grouping and the total, each task counted once" do
      expect(read(**range).slice("from", "to", "by", "seconds"))
        .to eq("from" => "2026-03-02", "to" => "2026-03-08", "by" => "project", "seconds" => 6300)
    end

    it "groups by project when no grouping is given" do
      expect(read(**range).fetch("by")).to eq("project")
    end

    it "sums each project, with the tasks that have no project last" do
      expect(groups(**range, by: "project").map { it.values_at("key", "name", "seconds") })
        .to eq([[gem.id, "gem", 3600], [site.id, "site", 5400], [nil, nil, 900]])
    end

    it "flags the projects that share time with another" do
      expect(groups(**range).map { it.values_at("name", "shared") })
        .to eq([["gem", true], ["site", true], [nil, false]])
    end

    it "lists each group's tasks with their time and whether that time is shared" do
      site_tasks = groups(**range).find { it.fetch("name") == "site" }.fetch("tasks")

      expect(site_tasks.map { it.values_at("id", "title", "seconds", "shared") })
        .to eq([[tasks[:both].id, "Ship the shared work", 3600, true],
                [tasks[:alone].id, "Polish the site", 1800, false]])
    end

    it "gives the sums the time screen shows" do
      sums = groups(**range, by: "project").map { Blog::Figures.hours(it.fetch("seconds")) }

      expect(sums).to eq(screen_rows(**range, by: "project"))
    end

    it "answers the MCP tool with the same JSON" do
      expect(mcp_answer("read_time_report", **range, by: "project")).to eq(read(**range, by: "project"))
    end
  end

  describe "grouped by tag" do
    before do
      worked("Tagged twice", at(2, 9), at(2, 10), tags: %w[ruby site])
      worked("Tagged once", at(3, 9), at(3, 9, 30), tags: %w[ruby])
      worked("Untagged", at(4, 9), at(4, 9, 15))
    end

    it "sums each tag, with the untagged tasks last" do
      expect(groups(**range, by: "tag").map { it.values_at("key", "name", "seconds") })
        .to eq([%w[ruby ruby] + [5400], %w[site site] + [3600], [nil, nil, 900]])
    end

    it "gives the sums the time screen shows" do
      sums = groups(**range, by: "tag").map { Blog::Figures.hours(it.fetch("seconds")) }

      expect(sums).to eq(screen_rows(**range, by: "tag"))
    end

    it "answers the MCP tool with the same JSON" do
      expect(mcp_answer("read_time_report", **range, by: "tag")).to eq(read(**range, by: "tag"))
    end
  end

  describe "grouped by day" do
    before do
      link(worked("Ship the shared work", at(2, 9), at(2, 10)), site, gem)
      worked("Answer email", at(4, 9), at(4, 9, 15))
    end

    it "sums each day in order, keyed by the day" do
      expect(groups(**range, by: "day").map { it.values_at("key", "name", "seconds") })
        .to eq([%w[2026-03-02 2026-03-02] + [3600], %w[2026-03-04 2026-03-04] + [900]])
    end

    it "flags no day, since a day never shares time" do
      expect(groups(**range, by: "day").map { it.fetch("shared") }).to eq([false, false])
    end

    it "gives the sums the time screen shows" do
      sums = groups(**range, by: "day").map { Blog::Figures.hours(it.fetch("seconds")) }

      expect(sums).to eq(screen_rows(**range, by: "day"))
    end

    it "answers the MCP tool with the same JSON" do
      expect(mcp_answer("read_time_report", **range, by: "day")).to eq(read(**range, by: "day"))
    end
  end

  it "answers no groups for a range with no time" do
    expect(read(**range)).to include("seconds" => 0, "groups" => [])
  end

  it "refuses a range that runs backward", :aggregate_failures do
    read(from: "2026-03-08", to: "2026-03-02")

    expect(status).to eq(422)
    expect(JSON.parse(last_response.body).dig("errors", "from")).to eq(["from comes after to"])
  end

  it "refuses a day it cannot read" do
    read(from: "nope", to: "2026-03-08")

    expect(status).to eq(422)
  end

  it "refuses a request with no range", :aggregate_failures do
    read

    expect(status).to eq(422)
    expect(JSON.parse(last_response.body).fetch("errors").keys).to contain_exactly("from", "to")
  end

  it "refuses a grouping it does not know" do
    read(**range, by: "year")

    expect(status).to eq(422)
  end
end
