# frozen_string_literal: true

RSpec.describe Shares::Jobs::QueueHeldTitleFetches, :commits do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:fetches) { Shares::Jobs::FetchShortLinkTitle }

  def held = Shares::Slice["relations.held_title_fetches"].to_a

  def perform = described_class.new.perform

  def redis_back = allow(fetches).to receive(:perform_async).and_call_original

  def redis_down = allow(fetches).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)

  def shorten = Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk" })

  before { allow(agent).to receive(:notify) }

  describe "shortening a link while Redis is down" do
    let!(:result) do
      redis_down
      shorten
    end

    it "makes the link" do
      expect(result.value!.destination).to eq("https://example.com/talk")
    end

    it "tells Honeybadger the queue could not be reached" do
      expect(agent).to have_received(:notify).with(RedisClient::CannotConnectError)
    end

    it "holds the title fetch" do
      expect(held.map { it[:short_link_id] }).to eq([result.value!.id])
    end

    it "fetches the title once Redis is back", :aggregate_failures do
      redis_back
      perform

      expect(fetches.jobs.map { it["args"] }).to eq([[result.value!.id]])
      expect(held).to be_empty
    end

    it "keeps what it holds while Redis stays down", :aggregate_failures do
      expect { perform }.to raise_error(RedisClient::CannotConnectError)
      expect(held.size).to eq(1)
    end

    it "queues the fetch only once when run twice" do
      redis_back
      2.times { perform }

      expect(fetches.jobs.size).to eq(1)
    end
  end

  describe "clearing a link's title while Redis is down" do
    let(:link) { shorten.value! }

    before do
      Shares::Slice["operations.set_short_link_title"].call(link.id, { title: "Old" })
      redis_down
      fields = { destination: link.destination, code: link.code, title: "" }
      Shares::Slice["operations.save_short_link"].call(link.id, fields)
    end

    it "holds the title fetch" do
      expect(held.map { it[:short_link_id] }).to eq([link.id])
    end
  end

  it "queues nothing when nothing is held" do
    perform

    expect(fetches.jobs).to be_empty
  end
end
