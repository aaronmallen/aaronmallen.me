# frozen_string_literal: true

RSpec.describe "Social webmentions", type: :request do
  let(:bridgy) { "https://brid.gy/like/mastodon/1" }
  let(:source) { "https://ada.example/notes/1" }
  let(:target) { "https://aaronmallen.me/writing/hello" }
  let(:webmention_repo) { Social::Slice["repos.webmention_repo"] }

  let!(:article) { create(:post, :published, slug: "hello") }

  def notify(**params) = post("/webmention", { source:, target: }.merge(params))

  def queued = Social::Jobs::VerifyWebmention.jobs.map { it["args"].first }

  def receipts = Social::Slice["relations.webmention_receipts"].count

  def sent_together(count)
    gate = Thread::Queue.new
    senders = Array.new(count) do |sent|
      Thread.new do
        gate.pop
        Rack::MockRequest.new(app).post("/webmention", params: { source: "#{source}/#{sent}", target: }).status
      end
    end

    count.times { gate.push(:go) }
    senders.map(&:value)
  end

  describe "a Bridgy mention" do
    it "is accepted while Bridgy is on" do
      notify(source: bridgy)

      expect([last_response.status, queued]).to eq([202, [bridgy]])
    end

    it "is rejected once Bridgy is off" do
      webmention_repo.update_settings(accept_bridgy: false)
      notify(source: bridgy)

      expect([last_response.status, queued]).to eq([400, []])
    end

    it "leaves other senders accepted once Bridgy is off" do
      webmention_repo.update_settings(accept_bridgy: false)
      notify

      expect(last_response.status).to eq(202)
    end
  end

  describe "a rejected notification" do
    {
      "a source that is the target" => { source: "https://aaronmallen.me/writing/hello" },
      "a source that is the target under another spelling" => { source: "https://AaronMallen.me/writing/hello/" },
      "a source that does not parse" => { source: "http://[bad" },
      "a source with no host" => { source: "https:///notes/1" },
      "a source that isn't http" => { source: "ftp://ada.example/notes/1" },
      "a target that isn't http" => { target: "ftp://aaronmallen.me/writing/hello" },
      "a target that isn't an article" => { target: "https://aaronmallen.me/tags/ruby" },
      "a target no post has" => { target: "https://aaronmallen.me/writing/nope" },
      "a source past 2048 bytes" => { source: "https://ada.example/#{'a' * 2029}" },
    }.each do |what, params|
      it "rejects #{what} and queues nothing" do
        notify(**params)

        expect([last_response.status, queued]).to eq([400, []])
      end
    end

    it "accepts a source of exactly 2048 bytes" do
      notify(source: "https://ada.example/#{'a' * 2028}")

      expect(last_response.status).to eq(202)
    end

    it "rejects everything while receiving is off" do
      webmention_repo.update_settings(receive: false)
      notify

      expect(last_response.status).to eq(400)
    end
  end

  describe "a target whose slug is no slug" do
    def receipt_post_ids = Social::Slice["relations.webmention_receipts"].pluck(:post_id)

    {
      "bytes that are not UTF-8" => ["%FF", nil],
      "a capital letter" => %w[Hello Hello],
      "an escaped space" => ["hello%20there", "hello there"],
      "an escaped slash" => ["hello%2Fthere", "hello/there"],
      "a reserved word" => %w[tags tags],
    }.each do |what, (escaped, slug)|
      it "rejects #{what} even when a post has it", :aggregate_failures do
        create(:post, :published, slug:) if slug
        notify(target: "https://aaronmallen.me/writing/#{escaped}")

        expect([last_response.status, queued]).to eq([400, []])
        expect(receipts).to eq(0)
      end
    end

    it "takes the post a valid slug names" do
      notify

      expect(receipt_post_ids).to eq([article.id])
    end
  end

  describe "one sender's notifications arriving together", :commits do
    before do
      Hanami.app.start(:honeybadger)
      lower_throttle_limit(:webmentions, to: 2)
    end

    it "stores and queues no more than the limit", :aggregate_failures do
      statuses = sent_together(5)

      expect(statuses.tally).to eq(202 => 2, 429 => 3)
      expect([receipts, queued.size]).to eq([2, 2])
    end
  end
end
