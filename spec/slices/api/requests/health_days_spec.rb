# frozen_string_literal: true

RSpec.describe "API health days", type: :request do
  let(:monday) { Date.new(2026, 9, 7) }
  let(:range) { { from: "2026-09-07", to: "2026-09-13" } }

  def read(token = api_token(%w[health]), **params) = call_api(:get, "/health/days", params, token:)

  describe "with the health scope" do
    let!(:workout) { create(:workout, kind: "RUNNING", started_at: at(monday, 7), minutes: 42, device: "Watch") }

    before do
      create(:health_day, day: monday + 1, minutes_asleep: 420, hrv: 48.5, resting_heart_rate: 54, steps: 8421)
      create(:commit, commit_date: monday + 1, commit_time: "22:15")
      create(:workout, started_at: at(monday + 7, 7))
    end

    it "answers one row a day for the range" do
      expect(read(**range).fetch("days").map { it.fetch("day") }).to eq((monday..(monday + 6)).map(&:iso8601))
    end

    it "gives each day its health beside its work" do
      expect(read(**range).fetch("days")[1]).to include(
        "minutes_asleep" => 420, "hrv" => 48.5, "resting_heart_rate" => 54, "steps" => 8421, "commits" => 1,
        "late_commits" => 1,
      )
    end

    it "leaves a day with no health data null" do
      expect(read(**range).fetch("days").first).to include("minutes_asleep" => nil, "hrv" => nil, "commits" => 0)
    end

    it "lists the range's workouts only" do
      expect(read(**range).fetch("workouts").map { it.values_at("id", "kind", "minutes", "device") })
        .to eq([[workout.id, "RUNNING", 42, "Watch"]])
    end

    it "gives the 30 day baselines" do
      expect(read(**range).fetch("baseline"))
        .to eq("minutes_asleep" => 420.0, "hrv" => 48.5, "resting_heart_rate" => 54.0)
    end

    it "gives no pattern while a group holds under 3 days" do
      expect(read(**range).fetch("patterns").values).to eq([nil] * 4)
    end

    it "answers as the document describes" do
      read(**range)

      expect(OpenAPI.answer_errors(last_request, last_response)).to be_empty
    end
  end

  it "fills a pattern once each group holds 3 days" do
    (0..13).each { create(:health_day, day: monday + it, resting_heart_rate: it < 7 ? 55 : 60) }

    expect(read(from: "2026-09-07", to: "2026-09-20").dig("patterns", "resting_heart_rate")).to eq(
      "subject" => { "days" => 7, "averages" => { "resting_heart_rate" => 60.0 } },
      "rest" => { "days" => 7, "averages" => { "resting_heart_rate" => 55.0 } },
    )
  end

  it "refuses a token with only read" do
    create(:health_day, day: monday, minutes_asleep: 420)

    expect(read(api_token(%w[read suggest write publish delete]), **range)).to eq(
      "error" => "insufficient_scope", "error_description" => "this endpoint needs a token with the health scope",
    )
  end

  it "refuses a range past a year" do
    read(from: "2025-01-01", to: "2026-09-13")

    expect(status).to eq(422)
  end

  it "refuses a range that runs backwards" do
    read(from: "2026-09-13", to: "2026-09-07")

    expect(status).to eq(422)
  end
end
