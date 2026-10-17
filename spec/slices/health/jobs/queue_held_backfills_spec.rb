# frozen_string_literal: true

RSpec.describe Health::Jobs::QueueHeldBackfills, :commits do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:backfills) { Health::Jobs::BackfillHealth }
  let(:today) { Blog::TimeZone.today }

  def held = Health::Slice["relations.held_health_backfills"].to_a

  def perform = described_class.new.perform

  def queue_backfill = Health::Slice["operations.queue_backfill"].call

  def redis_back = allow(backfills).to receive(:perform_async).and_call_original

  def redis_down = allow(backfills).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)

  before { allow(agent).to receive(:notify) }

  describe "asking for a backfill while Redis is down" do
    before do
      redis_down
      queue_backfill
    end

    it "tells Honeybadger the queue could not be reached" do
      expect(agent).to have_received(:notify).with(RedisClient::CannotConnectError)
    end

    it "holds the backfill from today" do
      expect(held.map { it[:last_day] }).to eq([today])
    end

    it "holds one backfill when asked twice" do
      queue_backfill

      expect(held.size).to eq(1)
    end

    it "queues the backfill once Redis is back", :aggregate_failures do
      redis_back
      perform

      expect(backfills.jobs.map { it["args"] }).to eq([[today.iso8601]])
      expect(held).to be_empty
    end

    it "keeps what it holds while Redis stays down", :aggregate_failures do
      expect { perform }.to raise_error(RedisClient::CannotConnectError)
      expect(held.size).to eq(1)
    end
  end

  it "queues nothing when nothing is held" do
    perform

    expect(backfills.jobs).to be_empty
  end
end
