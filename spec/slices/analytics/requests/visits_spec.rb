# frozen_string_literal: true

require "digest"

RSpec.describe "Visit counting", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:event_repo) { Analytics::Slice["repos.analytics_event_repo"] }

  def beacon(visit, agent: self.agent)
    post "/pulse", visit.to_json, "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent,
                                  "REMOTE_ADDR" => "203.0.113.7"
  end

  def read(seconds, name: "first", **)
    beacon({ kind: "read", path: "/writing/hello", read_seconds: seconds, view_token: token(name) }, **)
  end

  def stored = event_repo.analytics_events.order(:occurred_at, :id).to_a

  def token(name) = Digest::SHA256.hexdigest("view-#{name}")[0, 32]

  def view(name: "first", **) = beacon({ kind: "view", path: "/writing/hello", view_token: token(name), ** })

  describe "a view" do
    it "keeps only the host of the referrer" do
      view(referrer: "https://news.example/item?id=1")

      expect(stored.first.referrer_host).to eq("news.example")
    end

    it "keeps no referrer that runs past the cap" do
      view(referrer: "https://news.example/#{'a' * 2048}")

      expect(stored.first.referrer_host).to be_nil
    end

    it "counts a visit from the site itself as direct" do
      view(referrer: "http://example.org/writing")

      expect(stored.first.referrer_host).to be_nil
    end

    it "keeps no title when the page sent a blank one" do
      view(title: "   ")

      expect(stored.first.title).to be_nil
    end
  end

  describe "a read" do
    before do
      view
      view(name: "second")
    end

    it "stores the read time on the view the beacon names, not the latest of the page" do
      read(42)

      expect(stored.map(&:read_seconds)).to eq([42, 0])
    end

    it "leaves the stored time alone when a later read is shorter" do
      read(600)
      read(42)

      expect(stored.first.read_seconds).to eq(600)
    end

    it "stores twenty minutes for a read that runs past it" do
      read(86_400)

      expect(stored.first.read_seconds).to eq(1_200)
    end

    it "leaves another visitor's view alone" do
      read(42, agent: "Mozilla/5.0 Firefox/140.0")

      expect(stored.map(&:read_seconds)).to eq([0, 0])
    end
  end

  describe "views from one address that arrive together", :commits do
    let(:limit) { 5 }
    let(:sent) { limit + 3 }
    let!(:statuses) { checked_together }

    def checked_together
      lower_throttle_limit(:analytics, to: limit)
      arrived, release = hold_each_count
      senders = Array.new(sent) { view_request(it) }.map { |request| Thread.new { request.call } }
      sent.times { arrived.pop(timeout: 5) }
      sent.times { release << :go }
      senders.map(&:value)
    end

    def hold_each_count
      arrived = Thread::Queue.new
      release = Thread::Queue.new
      allow(event_repo).to receive(:count_from_address_since).and_wrap_original do |original, *args|
        original.call(*args).tap do
          arrived << true
          release.pop(timeout: 5)
        end
      end
      replace_component("repos.analytics_event_repo", event_repo)

      [arrived, release]
    end

    def view_request(index)
      body = { kind: "view", path: "/writing/hello", view_token: token("view-#{index}") }.to_json
      headers = { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => "203.0.113.7" }
      server = Rack::MockRequest.new(app)

      -> { server.post("/pulse", input: body, **headers).status }
    end

    it "stores no more than the limit" do
      expect(stored).to have(limit).items
    end

    it "tells every view past the limit it is throttled" do
      expect(statuses.tally).to eq(202 => limit, 429 => sent - limit)
    end
  end
end
