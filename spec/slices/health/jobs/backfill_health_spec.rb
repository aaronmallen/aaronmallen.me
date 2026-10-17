# frozen_string_literal: true

RSpec.describe Health::Jobs::BackfillHealth do
  def backfill(last = today) = described_class.new.perform(last.iso8601)

  def days = Health::Slice["relations.health_days"].to_a.map { it[:day] }

  def older_than(date)
    filter = %(daily_resting_heart_rate.date < "#{date.iso8601}")
    a_request(:get, %r{daily-resting-heart-rate/dataPoints\?}).with(query: hash_including(filter:, page_size: "1"))
  end

  def queued = described_class.jobs.map { it["args"] }

  def resting_on(date) = { dataPoints: [{ daily_resting_heart_rate: { date: google_date(date), beatsPerMinute: 55 } }] }

  def steps_on(date) = { rollupDataPoints: [{ civilStartTime: google_civil(date), steps: { countSum: "5000" } }] }

  describe "with Google Health connected" do
    before { connect_google }

    it "stores the 90 days up to the day it starts from" do
      stub_google_health(steps: steps_on(today - 89))
      backfill

      expect(days).to eq([today - 89])
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

    it "walks on past 90 days with no data while Google holds older ones" do
      stub_google_health(daily_resting_heart_rate: resting_on(today - 120))
      backfill

      expect(queued).to eq([[(today - 90).iso8601]])
    end

    it "asks Google only for data older than the empty chunk" do
      stub_google_health
      backfill

      expect(older_than(today - 89)).to have_been_made
    end

    it "imports the days before a 90-day gap" do
      stub_google_health(daily_resting_heart_rate: resting_on(today - 120))
      backfill
      backfill(today - 90)

      expect(days).to eq([today - 120])
    end

    it "raises when Google fails, so Sidekiq tries the chunk again" do
      stub_google_health
      stub_request(:get, %r{dataTypes/sleep/dataPoints\?}).to_return(status: 503)

      expect { backfill }.to raise_error(Health::Error, "Google answered 503")
    end

    it "raises when Google fails while it looks for older data" do
      stub_google_health
      stub_request(:get, %r{dataTypes/sleep/dataPoints\?.*page_size=1}).to_return(status: 503)

      expect { backfill }.to raise_error(Health::Error, "Google answered 503")
    end
  end

  it "stops while Google Health is not connected" do
    backfill

    expect(queued).to be_empty
  end
end
