# frozen_string_literal: true

RSpec.describe "API analytics", :frozen_clock, type: :request do
  def read(**params)
    window = { from: (today - 6).iso8601, to: today.iso8601 }.merge(params)
    get "/api/v1/analytics", window,
        { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    JSON.parse(last_response.body)
  end

  def roll_up(day, views:, visitors:) = create(:analytics_rollup, day:, views:, visitors:, read_seconds: views * 10)

  def status = last_response.status

  def today = Blog::TimeZone.today

  it "adds up the site's days inside the range with a 200" do
    roll_up(today - 1, views: 10, visitors: 4)

    expect([read.fetch("totals"), status])
      .to eq([{ "views" => 10, "visitors" => 4, "read_seconds" => 100, "read_throughs" => 0, "reach" => 0 }, 200])
  end

  it "gives each top path its title unmarked" do
    day = roll_up(today - 1, views: 50, visitors: 30).day
    create(:analytics_rollup_path, day:, path: "/writing/loud", views: 40, visitors: 20, bounces: 0)

    expect(read.fetch("paths").map { it.values_at("path", "views") }).to eq([["/writing/loud", 40]])
  end

  it "reads one page alone" do
    expect(read(path: "/writing/hello")).to include("path" => "/writing/hello", "clicks" => [])
  end

  it "answers what read_analytics answers, less the untrusted marks" do
    day = roll_up(today - 1, views: 50, visitors: 30).day
    create(:analytics_rollup_path, day:, path: "/writing/loud", views: 40, visitors: 20, bounces: 0)
    window = { from: (today - 6).iso8601, to: today.iso8601 }

    expect(read).to eq(trusted(mcp_answer("read_analytics", **window)))
  end

  it "refuses a since it cannot read with a 422" do
    expect([read(since: "this morning").fetch("message"), status])
      .to eq([API::Endpoints::ReadAnalytics::SINCE_REFUSAL, 422])
  end

  it "refuses a range longer than a year with a 422" do
    expect([read(from: (today - 400).iso8601).fetch("message"), status])
      .to eq([API::Helpers::DayWindow::TOO_LONG, 422])
  end
end
