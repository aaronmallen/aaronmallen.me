# frozen_string_literal: true

RSpec.describe "Feed fetch counting", type: :request do
  let(:feed_repo) { Analytics::Slice["repos.feed_fetch_repo"] }
  let(:reader) { "NetNewsWire (RSS Reader; https://netnewswire.com/)" }
  let(:today) { Blog::TimeZone.today }

  before { create(:post, :published, slug: "hello", tags: ["ruby"]) }

  def fetch(path = "/writing.atom", agent: reader, address: "203.0.113.7", **headers)
    get path, {}, { "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => address, **headers }
  end

  def readers = feed_repo.feed_readers.to_a.map { it.to_h.values_at(:day, :path, :readers) }

  def subscribers = feed_repo.feed_subscribers.to_a.map { it.to_h.values_at(:day, :path, :aggregator, :subscribers) }

  describe "an aggregator that names its subscribers" do
    inoreader = "Mozilla/5.0 (compatible; Inoreader/1.0; https://www.inoreader.com; 42 subscribers)"
    newsblur = "NewsBlur Feed Fetcher - 42 subscribers - https://www.newsblur.com/site/1/hello"

    [
      ["Feedly", "Feedly/1.0 (+https://feedly.com/poller.html; 42 subscribers; )", "feedly"],
      ["Inoreader", inoreader, "inoreader"],
      ["NewsBlur", newsblur, "newsblur"],
    ].each do |named, agent, aggregator|
      it "stores the count for #{named} that day" do
        fetch(agent:)

        expect(subscribers).to eq([[today, "/writing.atom", aggregator, 42]])
      end
    end

    it "keeps the later count of two on one day" do
      fetch(agent: "Feedly/1.0 (+https://feedly.com/poller.html; 42 subscribers; )")
      fetch(agent: "Feedly/1.0 (+https://feedly.com/poller.html; 40 subscribers; )")

      expect(subscribers).to eq([[today, "/writing.atom", "feedly", 40]])
    end

    it "keeps a count for each day" do
      fetch(agent: "Feedly/1.0 (42 subscribers)")
      allow(Time).to receive(:now).and_return(days_ahead(1))
      fetch(agent: "Feedly/1.0 (43 subscribers)")

      expect(subscribers.map(&:last)).to contain_exactly(42, 43)
    end

    it "keeps each feed's count apart" do
      fetch(agent: "Feedly/1.0 (42 subscribers)")
      fetch("/writing/tags/ruby.atom", agent: "Feedly/1.0 (7 subscribers)")

      counts = subscribers.map { it.values_at(1, 3) }

      expect(counts).to contain_exactly(["/writing.atom", 42], ["/writing/tags/ruby.atom", 7])
    end

    it "counts no daily reader for the aggregator" do
      fetch(agent: "Feedly/1.0 (42 subscribers)")

      expect(readers).to be_empty
    end

    it "counts a fetch that gets a 304", :aggregate_failures do
      fetch
      fetch(agent: "Feedly/1.0 (42 subscribers)", "HTTP_IF_NONE_MATCH" => last_response.headers["ETag"])

      expect(last_response.status).to eq(304)
      expect(subscribers.map(&:last)).to eq([42])
    end
  end

  describe "a feed reader with no subscriber count" do
    it "counts once a day however often it fetches" do
      3.times { fetch }

      expect(readers).to eq([[today, "/writing.atom", 1]])
    end

    it "counts two readers as two" do
      fetch
      fetch(address: "198.51.100.4")

      expect(readers).to eq([[today, "/writing.atom", 2]])
    end

    it "counts again the next day" do
      fetch
      allow(Time).to receive(:now).and_return(days_ahead(1))
      fetch

      expect(readers.map(&:last)).to eq([1, 1])
    end

    it "counts once in each feed it fetches" do
      fetch
      fetch("/writing/tags/ruby.atom")

      counts = readers.map { it.values_at(1, 2) }

      expect(counts).to contain_exactly(["/writing.atom", 1], ["/writing/tags/ruby.atom", 1])
    end

    it "counts a tag feed under its own path once after a move from another case" do
      fetch("/writing/tags/Ruby.atom")
      fetch(last_response.location)

      expect(readers.map { it.values_at(1, 2) }).to eq([["/writing/tags/ruby.atom", 1]])
    end

    it "keeps the daily hash, not the address" do
      fetch

      expect(feed_repo.feed_reader_hashes.to_a.map(&:reader_hash)).to all(match(/\A\h{64}\z/))
    end

    it "counts an aggregator that names no count as a reader" do
      fetch(agent: "Feedly/1.0 (+http://www.feedly.com/fetcher.html; like FeedFetcher-Google)")

      expect([readers.map(&:last), subscribers]).to eq([[1], []])
    end

    it "counts a fetch that gets a 304" do
      fetch(address: "198.51.100.4")
      fetch("HTTP_IF_NONE_MATCH" => last_response.headers["ETag"])

      expect(readers.map(&:last)).to eq([2])
    end
  end

  describe "an agent the site does not know that names a count" do
    [
      ["a plain name", "Feedbin feed-id:1234 - 42 subscribers"],
      ["a wrapped name", "Mozilla/5.0 (compatible; Bazqux/2.0; 42 subscribers)"],
      ["a long name", "#{'a' * 33} - 42 subscribers"],
      ["no name at all", "42 subscribers"],
    ].each do |named, agent|
      it "counts #{named} as a reader and stores no count" do
        fetch(agent:)

        expect([readers.map(&:last), subscribers]).to eq([[1], []])
      end
    end

    it "counts once a day however often it fetches" do
      3.times { fetch(agent: "Feedbin feed-id:1234 - 42 subscribers") }

      expect([readers.map(&:last), subscribers]).to eq([[1], []])
    end

    it "adds no subscriber row for any name it makes up" do
      %w[alpha beta gamma].each { fetch(agent: "Mozilla/5.0 (compatible; #{it}/1.0; 42 subscribers)") }

      expect(subscribers).to be_empty
    end
  end

  describe "a fetch the parser cannot read" do
    it "counts as a reader when the count is too large to store" do
      fetch(agent: "Feedly/1.0 (12345678901 subscribers)")

      expect([readers.map(&:last), subscribers]).to eq([[1], []])
    end
  end

  describe "a signed in fetch" do
    before { sign_in_to_admin }

    it "adds nothing", :aggregate_failures do
      fetch
      fetch(agent: "Feedly/1.0 (42 subscribers)")

      expect(readers).to be_empty
      expect(subscribers).to be_empty
    end
  end

  describe "a fetch that finds no feed" do
    it "adds nothing for a tag no post has" do
      fetch("/writing/tags/nothing.atom")

      expect(readers).to be_empty
    end

    it "adds nothing for a tag feed spelled in another case" do
      fetch("/writing/tags/Ruby.atom")

      expect(readers).to be_empty
    end

    it "adds nothing for a page past the end" do
      fetch("/writing.atom?page=9")

      expect(readers).to be_empty
    end
  end

  describe "the daily hashes" do
    let(:hashes) { feed_repo.feed_reader_hashes }

    def roll_up = Analytics::Jobs::RollUpAnalytics.new.perform

    it "leave the daily count in place" do
      fetch
      hashes.dataset.update(day: today - 91)
      roll_up

      expect(readers.map(&:last)).to eq([1])
    end
  end
end
