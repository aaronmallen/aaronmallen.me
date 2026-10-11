# frozen_string_literal: true

RSpec.describe Health::Jobs::BackfillHealth do
  let(:today) { Blog::TimeZone.today }

  def backfill(last = today) = described_class.new.perform(last.iso8601)

  def queued = described_class.jobs.map { it["args"] }

  def steps_on(date) = { rollupDataPoints: [{ civilStartTime: google_civil(date), steps: { countSum: "5000" } }] }

  describe "with Google Health connected" do
    before { connect_google }

    it "stores the 90 days up to the day it starts from" do
      stub_google_health(steps: steps_on(today - 89))
      backfill

      expect(Health::Slice["relations.health_days"].to_a.map { it[:day] }).to eq([today - 89])
    end

    it "asks Google for the 90 days before it once those held data" do
      stub_google_health(steps: steps_on(today))
      backfill

      expect(queued).to eq([[(today - 90).iso8601]])
    end

    it "stops once Google has no more data" do
      stub_google_health
      backfill

      expect(queued).to be_empty
    end

    it "raises when Google fails, so Sidekiq tries the chunk again" do
      stub_google_health
      stub_request(:get, %r{dataTypes/sleep/dataPoints\?}).to_return(status: 503)

      expect { backfill }.to raise_error(Health::Error, "Google answered 503")
    end
  end

  it "stops while Google Health is not connected" do
    backfill

    expect(queued).to be_empty
  end
end
