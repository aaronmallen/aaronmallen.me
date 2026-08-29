# frozen_string_literal: true

RSpec.describe "Social webmentions", type: :request do
  let(:bridgy) { "https://brid.gy/like/mastodon/1" }
  let(:source) { "https://ada.example/notes/1" }
  let(:target) { "https://aaronmallen.me/writing/hello" }
  let(:webmention_repo) { Social::Slice["repos.webmention_repo"] }

  before { create(:post, :published, slug: "hello") }

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

  describe "one sender's notifications arriving together", :commits do
    before { lower_throttle_limit(:webmentions, to: 2) }

    it "stores and queues no more than the limit", :aggregate_failures do
      statuses = sent_together(5)

      expect(statuses.tally).to eq(202 => 2, 429 => 3)
      expect([receipts, queued.size]).to eq([2, 2])
    end
  end

  describe "moderating a mention that is gone" do
    before { sign_in_to_admin }

    %w[approve spam].each do |verdict|
      it "answers 404 when asked to #{verdict} it" do
        post "/admin/webmentions/#{create(:webmention).id + 1}/#{verdict}", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
      end
    end
  end
end
