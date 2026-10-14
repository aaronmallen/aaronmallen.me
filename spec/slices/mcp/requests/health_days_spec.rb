# frozen_string_literal: true

RSpec.describe "MCP health days", type: :request do
  let(:monday) { Date.new(2026, 9, 7) }

  def access_token(scope)
    client = Spec::DB::Factories[:mcp].create(:oauth_client)
    mcp_connect(client, verifier: Blog::Types::NewSecret[], scope:).fetch("access_token")
  end

  def call_tool(scope, from: "2026-09-07", to: "2026-09-13")
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token(scope)}" }
    params = { name: "read_health_days", arguments: { from:, to: } }
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: }), headers
    JSON.parse(last_response.body)
  end

  before do
    create(:health_day, day: monday, minutes_asleep: 420, hrv: 48.5)
    create(:workout, kind: "RUNNING", started_at: Blog::TimeZone.local_time(2026, 9, 8, 7))
  end

  it "reads the day rows, workouts and patterns for a client with health" do
    expect(JSON.parse(call_tool("health").dig("result", "content", 0, "text"))).to include(
      "days" => include(include("day" => "2026-09-07", "minutes_asleep" => 420, "hrv" => 48.5)),
      "workouts" => [include("kind" => "RUNNING")],
      "patterns" => include("short_nights" => nil),
    )
  end

  it "refuses a range longer than 366 days" do
    expect(call_tool("health", from: "2025-09-07", to: "2026-09-08").dig("result", "content", 0, "text"))
      .to eq("give a range of 366 days or fewer")
  end

  it "reads a range of 366 days" do
    expect(JSON.parse(call_tool("health", from: "2025-09-08", to: "2026-09-08").dig("result", "content", 0, "text")))
      .to include("days" => include(include("day" => "2026-09-07")))
  end

  it "gives a client with only read no health data" do
    answer = call_tool("read")

    expect([answer.key?("result"), answer.dig("error", "data")])
      .to match([false, start_with("read_health_days needs the health permission")])
  end
end
