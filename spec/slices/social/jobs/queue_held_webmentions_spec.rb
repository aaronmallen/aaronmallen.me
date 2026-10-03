# frozen_string_literal: true

RSpec.describe Social::Jobs::QueueHeldWebmentions, type: :request do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:source) { "https://ada.example/notes/1" }
  let(:target) { "https://aaronmallen.me/writing/hello" }

  def entry = %(<div class="h-entry"><a class="u-in-reply-to" href="#{target}">re</a><p class="e-content">Hi</p></div>)

  def held = Social::Slice["relations.held_webmentions"].to_a

  def notify = post("/webmention", source:, target:)

  def perform = described_class.new.perform

  def queued = Social::Jobs::VerifyWebmention.jobs.map { it["args"] }

  def redis_back = allow(Social::Jobs::VerifyWebmention).to receive(:perform_async).and_call_original

  def redis_down
    allow(Social::Jobs::VerifyWebmention).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
  end

  def stored = Social::Slice["relations.webmentions"].to_a

  before do
    allow(agent).to receive(:notify)
    resolves_publicly("ada.example")
    create(:post, :published, slug: "hello")
  end

  describe "a webmention received while Redis is down" do
    before do
      redis_down
      notify
    end

    it "accepts the notification" do
      expect(last_response.status).to eq(202)
    end

    it "tells Honeybadger the queue could not be reached" do
      expect(agent).to have_received(:notify).with(RedisClient::CannotConnectError)
    end

    it "holds the check" do
      expect(held).to contain_exactly(include(source_url: source, target_url: target))
    end

    it "stores the mention once Redis is back" do
      stub_request(:get, source).to_return(body: entry)
      redis_back
      perform
      Social::Jobs::VerifyWebmention.drain

      expect(stored).to contain_exactly(include(source_url: source, status: "pending"))
    end

    it "lets go of what it queued" do
      redis_back
      perform

      expect(held).to be_empty
    end

    it "keeps what it holds while Redis stays down", :aggregate_failures do
      expect { perform }.to raise_error(RedisClient::CannotConnectError)
      expect(held.size).to eq(1)
    end

    it "queues each held check only once when run twice" do
      redis_back
      2.times { perform }

      expect(queued.size).to eq(1)
    end
  end

  it "queues nothing when nothing is held" do
    perform

    expect(queued).to be_empty
  end

  it "runs on the schedule the worker reads" do
    expect(Object.const_get(sidekiq_schedule("queue_held_webmentions").fetch("class"))).to eq(described_class)
  end
end
