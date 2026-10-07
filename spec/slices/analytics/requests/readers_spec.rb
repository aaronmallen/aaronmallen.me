# frozen_string_literal: true

RSpec.describe "Post reader counting", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:day) { 86_400 }
  let(:readers) { Analytics::Slice["db.rom"].gateways[:default].connection[:post_reader_hashes] }

  before { create(:post, :published, slug: "hello") }

  def stored = readers.order(:path, :reader_hash).select_map(%i[path reader_hash])

  def view(path: "/writing/hello", address: "203.0.113.7", agent: self.agent)
    post "/pulse", { kind: "view", path: }.to_json, "CONTENT_TYPE" => "application/json",
                                                    "HTTP_USER_AGENT" => agent.to_s,
                                                    "REMOTE_ADDR" => address
  end

  def view_later(days)
    allow(Time).to receive(:now).and_return(Time.now + (days * day))
    view
  end

  describe "a view of a post" do
    it "stores one row of the path and a hash" do
      view

      expect(stored).to contain_exactly(["/writing/hello", match(/\A\h{64}\z/)])
    end

    it "stores nothing more when the same reader comes back in a later month" do
      view
      view_later(40)

      expect(stored).to have(1).item
    end

    it "stores a row for each reader on another address" do
      view
      view(address: "198.51.100.4")

      expect(stored).to have(2).items
    end

    it "stores a row for each reader on another browser" do
      view
      view(agent: "Mozilla/5.0 (X11; Linux x86_64) Firefox/140.0")

      expect(stored).to have(2).items
    end

    it "gives one reader a different hash on each post" do
      create(:post, :published, slug: "other")
      view
      view(path: "/writing/other")

      expect(stored.map(&:last).uniq).to have(2).items
    end

    it "keeps only the path and the hash" do
      view

      expect(readers.first.keys).to contain_exactly(:path, :reader_hash)
    end
  end

  describe "a view near the end of a post's first 12 months" do
    before { create(:post, :published, slug: "old", published_at: Time.now - (360 * day)) }

    it "stores the reader" do
      view(path: "/writing/old")

      expect(stored).to have(1).item
    end
  end

  describe "a view more than 12 months after a post went up" do
    before { create(:post, :published, slug: "old", published_at: Time.now - (370 * day)) }

    it "stores nothing" do
      view(path: "/writing/old")

      expect(stored).to be_empty
    end

    it "still counts the view" do
      view(path: "/writing/old")

      expect(Analytics::Slice["repos.analytics_event_queries"].analytics_events.count).to eq(1)
    end
  end

  describe "a view that stores no reader" do
    it "stores nothing for a page that is not a post" do
      view(path: "/about")

      expect(stored).to be_empty
    end

    it "stores nothing while the operator is signed in" do
      sign_in_to_admin
      view

      expect(stored).to be_empty
    end

    it "stores nothing from a known bot" do
      view(agent: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")

      expect(stored).to be_empty
    end

    it "stores nothing past the throttle" do
      lower_throttle_limit(:analytics, to: 1)
      view(path: "/about")
      view

      expect(stored).to be_empty
    end
  end
end
