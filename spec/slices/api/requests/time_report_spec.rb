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
      sums = groups(**range, by: "project").map { Blog::Helpers::Figures.hours(it.fetch("seconds")) }

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
      sums = groups(**range, by: "tag").map { Blog::Helpers::Figures.hours(it.fetch("seconds")) }

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
      sums = groups(**range, by: "day").map { Blog::Helpers::Figures.hours(it.fetch("seconds")) }

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

  describe "tasks that ran at the same time" do
    def hour(title, tags: []) = worked(title, at(2, 9), at(2, 10), tags:)

    it "counts the hour once in the total while each task keeps its hour" do
      ids = %w[one two three].map { hour(it).id }

      rows = groups(**range, by: "day").first.fetch("tasks").map { it.values_at("id", "seconds") }

      expect([read(**range).fetch("seconds"), rows]).to match([3600, match_array(ids.map { [it, 3600] })])
    end

    it "gives a project they share one hour and says they overlapped" do
      2.times { link(hour("Side by side #{it}"), site) }

      expect(groups(**range, by: "project").map { it.values_at("name", "seconds", "overlapped") })
        .to eq([["site", 3600, true]])
    end

    it "gives each of two projects an hour and the total an hour" do
      link(hour("For the site"), site)
      link(hour("For the gem"), gem)

      found = groups(**range, by: "project").map { it.values_at("name", "seconds", "overlapped") }

      expect([read(**range).fetch("seconds"), found]).to eq([3600, [["gem", 3600, false], ["site", 3600, false]]])
    end

    it "counts a task in two projects once in the total" do
      link(hour("Shared"), site, gem)
      hour("Loose")

      expect(read(**range, by: "project").fetch("seconds")).to eq(3600)
    end

    it "merges within a tag" do
      hour("Ruby one", tags: %w[ruby])
      hour("Ruby two", tags: %w[ruby])

      found = groups(**range, by: "tag").map { it.values_at("name", "seconds", "overlapped") }

      expect(found).to eq([["ruby", 3600, true]])
    end

    it "merges short spans inside a long one" do
      worked("Long", at(2, 9), at(2, 12))
      worked("Inside early", at(2, 9, 30), at(2, 10))
      worked("Inside late", at(2, 11), at(2, 11, 30))

      expect(sums(**range)).to eq([["2026-03-02", 3 * 3600]])
    end

    it "flags no overlap for tasks that ran apart" do
      worked("Morning", at(2, 9), at(2, 10))
      worked("Noon", at(2, 12), at(2, 13))

      expect(groups(**range, by: "day").map { it.values_at("seconds", "overlapped") }).to eq([[7200, false]])
    end

    it "lands overlap that crosses midnight on each site day" do
      spent("Late", [at(2, 22), at(3, 2)])
      spent("Later", [at(2, 23), at(3, 1)])

      expect(sums(**range)).to eq([["2026-03-02", 7200], ["2026-03-03", 7200]])
    end

    it "counts a running task beside a closed one once up to now" do
      today = Blog::TimeZone.today
      running = create(:task, :in_progress)
      create(:work_session, task_id: running.id, started_at: Time.now - 1200)
      spent("Closed beside it", [Time.now - 600, Time.now - 300], completed_at: Time.now)

      expect(read(from: (today - 1).iso8601, to: today.iso8601).fetch("seconds")).to be_within(5).of(1200)
    end
  end

  describe "a hand-set total" do
    def beside(title) = worked(title, at(2, 9), at(2, 10))

    it "adds to the merged total as it stands" do
      beside("Ran alongside")
      spent("Set by hand", [at(2, 9), at(2, 10)], total: 3 * 3600, completed_at: at(2, 10))

      expect([read(**range).fetch("seconds"), sums(**range)]).to eq([3 * 3600, [["2026-03-02", 3 * 3600]]])
    end

    it "takes from the merged total as it stands" do
      beside("Ran alongside")
      spent("Set by hand", [at(2, 9), at(2, 10)], total: 1800, completed_at: at(2, 10))

      expect(read(**range).fetch("seconds")).to eq(1800)
    end

    it "lands on the day the task closed, not across its sessions" do
      spent("Set by hand", [at(2, 9), at(2, 10)], [at(3, 9), at(3, 12)], total: 5 * 3600, completed_at: at(5, 15))

      expect(sums(**range)).to eq([["2026-03-02", 3600], ["2026-03-03", 3 * 3600], ["2026-03-05", 3600]])
    end

    it "lands on the task's last session day while the task is open" do
      task = create(:task, :in_progress, worked_seconds: 2 * 3600)
      create(:work_session, task_id: task.id, started_at: at(3, 9), ended_at: at(3, 10))

      expect(sums(**range)).to eq([["2026-03-03", 2 * 3600]])
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
