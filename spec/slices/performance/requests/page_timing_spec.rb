# frozen_string_literal: true

require "digest"

RSpec.describe "Timing a page in the browser", type: :request do
  let(:agent) do
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
  end
  let(:timing) { { ttfb: 120, dom_content_loaded: 480, load: 910, lcp: 640 } }
  let(:token) { Digest::SHA256.hexdigest("timed")[0, 32] }

  before do
    create(:post, :published, slug: "hello")
    beacon({ kind: "view", path: "/writing/hello", title: "Hello", view_token: token })
  end

  def beacon(visit, agent: self.agent)
    post "/pulse", visit.to_json, "CONTENT_TYPE" => "application/json",
                                  "HTTP_USER_AGENT" => agent,
                                  "REMOTE_ADDR" => "203.0.113.7"
  end

  def events = Analytics::Slice["db.rom"].relations[:analytics_events].to_a

  def read(agent: self.agent, path: "/writing/hello", **visit)
    beacon({ kind: "read", path:, read_seconds: 42, view_token: token, **visit }, agent:)
  end

  def rows = Performance::Slice["db.rom"].relations[:performance_pages].to_a

  context "when a read carries the page's timing" do
    before { read(timing:) }

    it "accepts the beacon" do
      expect(last_response.status).to eq(202)
    end

    it "stores the timing with the route pattern and device class" do
      expect(rows).to contain_exactly(
        include(route: "/writing/:slug", device_class: "mobile", ttfb: 120, dom_content_loaded: 480, load: 910,
                lcp: 640),
      )
    end

    it "stores no visitor hash or address" do
      expect(rows.first.keys).to contain_exactly(
        :id, :route, :device_class, :ttfb, :dom_content_loaded, :load, :lcp, :occurred_at, :created_at, :updated_at,
      )
    end

    it "still stores the read time on the view" do
      expect(events.first[:read_seconds]).to eq(42)
    end
  end

  it "stores timing with no LCP from a browser that has none" do
    read(timing: timing.except(:lcp))

    expect(rows).to contain_exactly(include(load: 910, lcp: nil))
  end

  it "stores nothing for a read with no timing" do
    read

    expect(rows).to be_empty
  end

  {
    "a timing that is no object" => "fast",
    "a missing load" => { ttfb: 120, dom_content_loaded: 480 },
    "a fraction of a millisecond" => { ttfb: 120.4, dom_content_loaded: 480, load: 910 },
    "a time in words" => { ttfb: "soon", dom_content_loaded: 480, load: 910 },
    "a negative time" => { ttfb: -5, dom_content_loaded: 480, load: 910 },
    "times out of order" => { ttfb: 120, dom_content_loaded: 910, load: 480 },
    "a time past ten minutes" => { ttfb: 120, dom_content_loaded: 480, load: 600_001 },
    "a negative LCP" => { ttfb: 120, dom_content_loaded: 480, load: 910, lcp: -1 },
  }.each do |named, nonsense|
    context "with #{named}" do
      before { read(timing: nonsense) }

      it "still accepts the beacon" do
        expect(last_response.status).to eq(202)
      end

      it "still stores the read time" do
        expect(events.first[:read_seconds]).to eq(42)
      end

      it "stores no timing" do
        expect(rows).to be_empty
      end
    end
  end

  it "stores no timing for a read that matches no view" do
    read(timing:, view_token: "0" * 32)

    expect(rows).to be_empty
  end

  it "stores no timing from a bot" do
    read(timing:, agent: "Googlebot/2.1 (+http://www.google.com/bot.html)")

    expect(rows).to be_empty
  end

  it "stores no timing while the owner is signed in" do
    sign_in_to_admin
    read(timing:)

    expect(rows).to be_empty
  end

  it "keeps the visit when the timing row cannot be written" do
    mutations = Performance::Slice["repos.timing_mutations"]
    allow(mutations).to receive(:record_page).and_raise(Sequel::DatabaseError)
    replace_component("repos.timing_mutations", mutations)
    read(timing:)

    expect(last_response.status).to eq(202)
  end
end
