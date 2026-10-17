# frozen_string_literal: true

RSpec.describe "MCP health days", type: :request do
  let(:monday) { Date.new(2026, 9, 7) }

  def mcp_scopes = %w[health]

  def read_days(from: "2026-09-07", to: "2026-09-13") = mcp_text("read_health_days", from:, to:)

  before do
    create(:health_day, day: monday, minutes_asleep: 420, hrv: 48.5)
    create(:workout, kind: "RUNNING", started_at: Blog::TimeZone.local_time(2026, 9, 8, 7))
  end

  it "reads the day rows, workouts and patterns for a client with health" do
    expect(JSON.parse(read_days)).to include(
      "days" => include(include("day" => "2026-09-07", "minutes_asleep" => 420, "hrv" => 48.5)),
      "workouts" => [include("kind" => "RUNNING")],
      "patterns" => include("short_nights" => nil),
    )
  end

  it "refuses a range longer than 366 days" do
    expect(read_days(from: "2025-09-07", to: "2026-09-08")).to eq("give a range of 366 days or fewer")
  end

  it "reads a range of 366 days" do
    expect(JSON.parse(read_days(from: "2025-09-08", to: "2026-09-08")))
      .to include("days" => include(include("day" => "2026-09-07")))
  end

  describe "a client with only read" do
    def mcp_scopes = %w[read]

    it "gets no health data" do
      expect([mcp_call("read_health_days", from: "2026-09-07", to: "2026-09-13"), mcp_reply.dig("error", "data")])
        .to match([nil, start_with("read_health_days needs the health permission")])
    end
  end
end
