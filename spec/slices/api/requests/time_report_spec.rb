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

  def spent(title, *spans, total: spans.sum { |from, to| (to - from).to_i }, **attributes)
    task = create(:task, :done, title:, worked_seconds: total, **attributes)
    spans.each { |from, to| create(:work_session, task_id: task.id, started_at: from, ended_at: to) }
    task
  end

  def status = last_response.status

  def sums(**) = groups(**, by: "day").map { it.values_at("key", "seconds") }

  def worked(title, from, to, tags: []) = spent(title, [from, to], tags:)

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
      expect(read(**range, by: "project").slice("from", "to", "by", "seconds"))
        .to eq("from" => "2026-03-02", "to" => "2026-03-08", "by" => "project", "seconds" => 6300)
    end

    it "sums each project, with the tasks that have no project last" do
      expect(groups(**range, by: "project").map { it.values_at("key", "name", "seconds") })
        .to eq([[gem.id, "gem", 3600], [site.id, "site", 5400], [nil, nil, 900]])
    end

    it "flags the projects that share time with another" do
      expect(groups(**range, by: "project").map { it.values_at("name", "shared") })
        .to eq([["gem", true], ["site", true], [nil, false]])
    end

    it "lists each group's tasks with their time and whether that time is shared" do
      site_tasks = groups(**range, by: "project").find { it.fetch("name") == "site" }.fetch("tasks")

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

    it "groups by tag when no grouping is given" do
      expect(read(**range)).to eq(read(**range, by: "tag"))
    end

    it "groups the MCP tool by tag when no grouping is given" do
      expect(mcp_answer("read_time_report", **range)).to eq(read(**range, by: "tag"))
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

  describe "a session that crosses the range" do
    let!(:task) { spent("Late nights", [at(1, 23), at(2, 1)], [at(8, 23), at(9, 2)]) }

    it "counts only the part inside the range" do
      expect([sums(**range), read(**range).fetch("seconds")])
        .to eq([[["2026-03-02", 3600], ["2026-03-08", 3600]], 7200])
    end

    it "lists its task under the day it counts on" do
      expect(groups(**range, by: "day").first.fetch("tasks").map { it.fetch("id") }).to eq([task.id])
    end
  end

  it "counts a running session up to now" do
    task = create(:task, :in_progress)
    create(:work_session, task_id: task.id, started_at: Time.now - 600)
    today = Blog::TimeZone.today

    expect(read(from: (today - 1).iso8601, to: today.iso8601).fetch("seconds")).to be_within(5).of(600)
  end

  describe "a hand-set total" do
    it "spreads across the task's sessions by their length" do
      spent("Set by hand", [at(2, 9), at(2, 10)], [at(3, 9), at(3, 12)], total: 2 * 3600)

      expect(sums(**range)).to eq([["2026-03-02", 1800], ["2026-03-03", 5400]])
    end

    it "spreads over sessions outside the range too" do
      spent("Set by hand", [at(2, 9), at(2, 10)], [at(10, 9), at(10, 10)], total: 4 * 3600)

      expect(sums(**range)).to eq([["2026-03-02", 7200]])
    end

    it "lands on the day the task closed when it has no sessions" do
      spent("Set by hand", total: 2700, completed_at: at(5, 15))

      expect(sums(**range)).to eq([["2026-03-05", 2700]])
    end

    it "is left out when it has no sessions and the task never closed" do
      create(:task, worked_seconds: 2700)

      expect(sums(**range)).to eq([])
    end

    it "is left out when the task closed outside the range" do
      spent("Set by hand", total: 2700, completed_at: at(9, 15))

      expect(sums(**range)).to eq([])
    end
  end

  it "lists each group's tasks with their time in the range, most first" do
    small = worked("small", at(2, 9), at(2, 9, 20))
    big = spent("big", [at(2, 10), at(2, 12)], [at(12, 10), at(12, 11)])

    expect(groups(**range, by: "day").first.fetch("tasks").map { it.values_at("id", "title", "seconds") })
      .to eq([[big.id, "big", 7200], [small.id, "small", 1200]])
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
